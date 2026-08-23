from sen import (
    CommandKind,
    Plot,
    Text,
    TextKind,
    TypstOptions,
    build_render_plan,
    encode_svg,
)
from sen.svg import _rewrite_typst_ids
from sen.typst import _shell_quote
from std.collections import List
from std.testing import (
    TestSuite,
    assert_equal,
    assert_raises,
    assert_true,
)


comptime FAKE_TYPST = "tests/fixtures/fake_typst.sh"


def _plot() raises -> Plot:
    var x: List[Float64] = [0.0, 1.0]
    var y: List[Float64] = [0.0, 1.0]
    return Plot().with_line(x, y)


def test_typst_options_have_bounded_defaults_and_value_semantics() raises:
    var options = TypstOptions()
    options.validate()
    assert_equal(options.executable(), "typst")
    assert_equal(options.timeout_seconds(), 10)
    assert_equal(options.max_source_bytes(), 65_536)
    assert_equal(options.max_output_bytes(), 8_388_608)
    assert_equal(options.id_prefix(), "sen-typst")
    assert_true(options == TypstOptions())

    var namespaced = options.with_id_prefix("report-panel-2")
    assert_equal(namespaced.id_prefix(), "report-panel-2")
    assert_true(namespaced != options)

    with assert_raises(contains="Typst executable must not be empty"):
        TypstOptions(executable="").validate()
    with assert_raises(contains="Typst timeout must be within 1..300"):
        TypstOptions(timeout_seconds=0).validate()
    with assert_raises(contains="Typst ID prefix must contain 1..64"):
        TypstOptions(id_prefix="").validate()
    with assert_raises(contains="Typst ID prefix must match"):
        _ = options.with_id_prefix("9-invalid")
    with assert_raises(contains="Typst ID prefix must match"):
        TypstOptions(id_prefix="plot prefix").validate()
    with assert_raises(contains="Typst ID prefix must match"):
        TypstOptions(id_prefix="図").validate()


def test_posix_shell_quoting_handles_spaces_quotes_and_metacharacters() raises:
    assert_equal(_shell_quote("simple"), "'simple'")
    assert_equal(_shell_quote("a b'$HOME;z"), "'a b'\"'\"'$HOME;z'")


def test_plain_text_never_starts_or_validates_a_typst_process() raises:
    var plot = _plot().with_title("dependency-free")
    var svg = plot.render_svg(TypstOptions(executable="/path/does/not/exist"))

    assert_true('<text class="sen-title"' in svg)
    assert_true('class="sen-title sen-typst"' not in svg)
    assert_true(">dependency-free</text>" in svg)


def test_fluent_typst_title_and_axis_labels_compile_into_nested_svg() raises:
    var plot = (
        _plot()
        .with_title(Text.typst_math("$ integral_0^1 x dif x $"))
        .with_xlabel(Text.typst_math("$ x $"))
        .with_ylabel(Text.typst_math("$ f(x) $"))
    )
    var svg = plot.render_svg(TypstOptions(executable=FAKE_TYPST))

    assert_true(plot.figure().title_kind() == TextKind.TYPST_MATH)
    assert_true(plot.figure().x_label_kind() == TextKind.TYPST_MATH)
    assert_true(plot.figure().y_label_kind() == TextKind.TYPST_MATH)
    assert_true('class="sen-title sen-typst"' in svg)
    assert_true('class="sen-x-label sen-typst"' in svg)
    assert_true('class="sen-y-label sen-typst"' in svg)
    assert_true('transform="rotate(-90 ' in svg)
    assert_true('id="sen-typst-sen-title-' in svg)
    assert_true('id="sen-typst-sen-x-label-' in svg)
    assert_true('id="sen-typst-sen-y-label-' in svg)
    assert_true('-sen-fake-typst"' in svg)


def test_repeated_typst_roles_include_unique_deterministic_command_indices() raises:
    var plot = _plot().with_title(Text.typst_math("$ x $"))
    var plan = build_render_plan(plot.figure())
    var title_index = -1
    for index in range(plan.command_count()):
        if plan.commands[index].kind == CommandKind.TITLE:
            title_index = index
            break
    assert_true(title_index >= 0)
    var duplicate = plan.commands[title_index].copy()
    plan.commands.append(duplicate^)
    var duplicate_index = plan.command_count() - 1
    var options = TypstOptions(executable=FAKE_TYPST)

    var first = encode_svg(plan, options)
    var second = encode_svg(plan, options)
    var first_id = (
        String('id="sen-typst-sen-title-') + String(title_index) + '-sen-fake-typst"'
    )
    var duplicate_id = (
        String('id="sen-typst-sen-title-')
        + String(duplicate_index)
        + '-sen-fake-typst"'
    )
    assert_true(first_id in first)
    assert_true(duplicate_id in first)
    assert_true(first_id != duplicate_id)
    assert_equal(first, second)


def test_typst_prefixes_separate_inlined_figures_without_losing_determinism() raises:
    var plot = _plot().with_title(Text.typst_math("$ x $"))
    var first_options = TypstOptions(executable=FAKE_TYPST).with_id_prefix("figure-a")
    var second_options = TypstOptions(executable=FAKE_TYPST).with_id_prefix("figure-b")

    var first = plot.render_svg(first_options)
    var repeated = plot.render_svg(first_options)
    var second = plot.render_svg(second_options)
    assert_equal(first, repeated)
    assert_true('id="figure-a-sen-title-' in first)
    assert_true('id="figure-b-sen-title-' in second)
    assert_true('id="figure-b-' not in first)
    assert_true(first != second)


def test_typst_id_rewrite_covers_definitions_href_and_url_references() raises:
    var compiled = String(
        '<svg><defs><path id="glyph"/></defs><use href="#glyph"/>'
        '<path fill="url(#glyph)"/></svg>'
    )
    var rewritten = _rewrite_typst_ids(compiled, "figure-a-sen-title-17-")

    assert_true('id="figure-a-sen-title-17-glyph"' in rewritten)
    assert_true('href="#figure-a-sen-title-17-glyph"' in rewritten)
    assert_true("url(#figure-a-sen-title-17-glyph)" in rewritten)


def test_typst_failure_surfaces_captured_diagnostics_and_status() raises:
    var plot = _plot().with_title(Text.typst_math("SEN_TYPST_FAIL"))

    with assert_raises(
        contains="Typst compilation failed with status 7: synthetic Typst diagnostic"
    ):
        _ = plot.render_svg(TypstOptions(executable=FAKE_TYPST))


def test_missing_typst_executable_is_never_reported_as_empty_success() raises:
    var plot = _plot().with_title(Text.typst_math("$ x $"))

    with assert_raises(contains="Typst compilation failed with status 127"):
        _ = plot.render_svg(
            TypstOptions(executable="/sen-definitely-missing/bin/typst-does-not-exist")
        )


def test_typst_watchdog_turns_a_wall_timeout_into_a_clear_error() raises:
    var plot = _plot().with_title(Text.typst_math("SEN_TYPST_SLEEP"))

    with assert_raises(contains="Typst compilation exceeded 1 seconds"):
        _ = plot.render_svg(TypstOptions(executable=FAKE_TYPST, timeout_seconds=1))


def test_typst_source_and_output_limits_are_enforced_before_unbounded_reads() raises:
    var source_limited = _plot().with_title(Text.typst_math("$ abcdefghijkl $"))
    with assert_raises(contains="Typst source exceeds the configured byte limit"):
        _ = source_limited.render_svg(
            TypstOptions(executable=FAKE_TYPST, max_source_bytes=4)
        )

    var output_limited = _plot().with_title(Text.typst_math("$ x $"))
    with assert_raises(contains="Typst SVG exceeds the configured byte limit"):
        _ = output_limited.render_svg(
            TypstOptions(executable=FAKE_TYPST, max_output_bytes=32)
        )


def test_xml_forbidden_controls_are_rejected_before_text_encoding() raises:
    var plot = _plot().with_title(String("bad\x01title"))
    with assert_raises(contains="scalar forbidden by XML 1.0"):
        _ = plot.render_svg()


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
