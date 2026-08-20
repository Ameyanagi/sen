from sen import Figure, LineSeries, Margins, PlotPoint, render_svg
from sen.svg import _escape_xml, _format_decimal, _format_svg_number, _tick_label
from std.testing import TestSuite, assert_equal, assert_raises, assert_true


def fixture_margins() raises -> Margins:
    return Margins(24.0, 8.0, 8.0, 20.0)


def single_line_figure() raises -> Figure:
    var line = LineSeries()
    line.append(PlotPoint(0.0, 0.0))
    line.append(PlotPoint(1.0, 1.0))
    line.append(PlotPoint(2.0, 0.0))
    var figure = Figure()
    figure.add_line(line^)
    return figure^


def two_series_figure() raises -> Figure:
    var rising = LineSeries()
    rising.append(PlotPoint(0.0, 0.0))
    rising.append(PlotPoint(2.0, 2.0))
    var falling = LineSeries()
    falling.append(PlotPoint(0.0, 2.0))
    falling.append(PlotPoint(2.0, 0.0))
    var figure = Figure()
    figure.add_line(rising^)
    figure.add_line(falling^)
    return figure^


def gap_figure() raises -> Figure:
    var line = LineSeries()
    line.append(PlotPoint(0.0, 0.0))
    line.append(PlotPoint(1.0, 1.0))
    line.start_segment(PlotPoint(2.0, 1.0))
    line.append(PlotPoint(3.0, 0.0))
    var figure = Figure()
    figure.add_line(line^)
    return figure^


def read_fixture(path: StringSlice) raises -> String:
    with open(path, "r") as fixture:
        return fixture.read()


def count_occurrences(text: StringSlice, needle: StringSlice) -> Int:
    var count = 0
    var index = 0
    while index + needle.byte_length() <= text.byte_length():
        if text[byte = index : index + needle.byte_length()] == needle:
            count += 1
            index += needle.byte_length()
        else:
            index += 1
    return count


def test_single_line_golden_fixture_is_byte_exact() raises:
    var figure = single_line_figure()
    var actual = render_svg(figure, 120.0, 80.0, fixture_margins())
    assert_equal(actual, read_fixture("tests/fixtures/single_line.svg"))


def test_two_series_golden_fixture_is_byte_exact() raises:
    var figure = two_series_figure()
    var actual = render_svg(figure, 120.0, 80.0, fixture_margins())
    assert_equal(actual, read_fixture("tests/fixtures/two_series.svg"))


def test_gap_golden_fixture_is_byte_exact() raises:
    var figure = gap_figure()
    var actual = render_svg(figure, 120.0, 80.0, fixture_margins())
    assert_equal(actual, read_fixture("tests/fixtures/segment_gap.svg"))


def test_xml_escape_covers_predefined_entities_and_unicode() raises:
    assert_equal(
        _escape_xml("A&B <tag> \"quote\" 'apostrophe' 雪"),
        "A&amp;B &lt;tag&gt; &quot;quote&quot; &apos;apostrophe&apos; 雪",
    )


def test_fixed_decimal_formatting_rules() raises:
    assert_equal(_format_decimal(1.2345, 3), "1.235")
    assert_equal(_format_decimal(-1.2345, 3), "-1.235")
    assert_equal(_format_svg_number(12.3401), "12.34")
    assert_equal(_format_svg_number(8.0), "8")
    assert_equal(_format_svg_number(-0.0004), "0")
    assert_equal(_format_svg_number(-0.0005), "-0.001")
    with assert_raises(contains="SVG numbers must be finite"):
        _ = _format_svg_number(Float64("nan"))


def test_tick_labels_follow_step_magnitude() raises:
    assert_equal(_tick_label(0.2, 0.2), "0.2")
    assert_equal(_tick_label(400000000.0, 200000000.0), "400000000")
    assert_equal(_tick_label(0.0000004, 0.0000002), "4e-7")


def test_rendering_is_deterministic_and_flips_y_coordinates() raises:
    var figure = single_line_figure()
    var first = render_svg(figure, 120.0, 80.0, fixture_margins())
    var second = render_svg(figure, 120.0, 80.0, fixture_margins())

    assert_equal(first, second)
    assert_equal(count_occurrences(first, "<polyline "), 1)
    assert_equal(
        count_occurrences(first, 'points="24,60 68,8 112,60"'),
        1,
    )
    assert_true(first.endswith("</svg>\n"))
    assert_true(not first.endswith("</svg>\n\n"))


def test_segment_gaps_emit_one_polyline_per_connected_segment() raises:
    var figure = gap_figure()
    var svg = render_svg(figure, 120.0, 80.0, fixture_margins())
    assert_equal(count_occurrences(svg, "<polyline "), 2)


def test_render_rejects_figures_without_points() raises:
    var empty = Figure()
    with assert_raises(contains="empty figure has no data bounds"):
        _ = render_svg(empty, 120.0, 80.0)

    var only_empty_lines = Figure()
    only_empty_lines.add_line(LineSeries())
    with assert_raises(contains="empty figure has no data bounds"):
        _ = render_svg(only_empty_lines, 120.0, 80.0)


def test_constant_domains_use_documented_padding() raises:
    var line = LineSeries()
    line.append(PlotPoint(2.0, -4.0))
    var figure = Figure()
    figure.add_line(line^)
    var svg = render_svg(figure, 120.0, 80.0, fixture_margins())

    assert_equal(count_occurrences(svg, "<polyline "), 1)
    assert_equal(count_occurrences(svg, 'points="68,34"'), 1)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
