from sen import Figure, LineSeries, Margins, MissingPolicy, PlotPoint, render_svg
from sen.svg import _escape_xml, _format_decimal, _format_svg_number, _tick_label
from std.collections import List
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


def titled_labels_figure() raises -> Figure:
    var xs: List[Float64] = [0.0, 1.0, 2.0]
    var ys: List[Float64] = [0.0, 1.0, 0.0]
    var figure = Figure()
    figure.line(xs, ys)
    figure.set_title("Deterministic <plot>")
    figure.set_x_label("x & time")
    figure.set_y_label("value 'y'")
    return figure^


def scatter_figure() raises -> Figure:
    var xs: List[Float64] = [0.0, 0.5, 1.0, 1.5, 2.0]
    var ys: List[Float64] = [0.0, 0.5, 1.0, 0.5, 0.0]
    var figure = Figure()
    figure.scatter(xs, ys)
    return figure^


def missing_segment_figure() raises -> Figure:
    var nan = Float64("nan")
    var xs: List[Float64] = [0.0, 1.0, nan, nan, 3.0, 4.0]
    var ys: List[Float64] = [0.0, 1.0, nan, 0.5, 1.0, 0.0]
    var figure = Figure()
    figure.line(xs, ys, missing=MissingPolicy.SEGMENT)
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


def first_occurrence(text: StringSlice, needle: StringSlice, start: Int = 0) -> Int:
    var index = start
    while index + needle.byte_length() <= text.byte_length():
        if text[byte = index : index + needle.byte_length()] == needle:
            return index
        index += 1
    return -1


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


def test_titled_labels_golden_fixture_is_byte_exact() raises:
    var figure = titled_labels_figure()
    var actual = render_svg(figure, 120.0, 80.0, fixture_margins())
    assert_equal(actual, read_fixture("tests/fixtures/titled_labels.svg"))


def test_scatter_golden_fixture_is_byte_exact() raises:
    var figure = scatter_figure()
    var actual = render_svg(figure, 120.0, 80.0, fixture_margins())
    assert_equal(actual, read_fixture("tests/fixtures/scatter_basic.svg"))


def test_missing_segment_golden_fixture_is_byte_exact() raises:
    var figure = missing_segment_figure()
    var actual = render_svg(figure, 120.0, 80.0, fixture_margins())
    assert_equal(actual, read_fixture("tests/fixtures/missing_segment.svg"))


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


def test_lines_and_scatters_render_in_interleaved_insertion_order() raises:
    var xs: List[Float64] = [0.0, 1.0]
    var rising: List[Float64] = [0.0, 1.0]
    var falling: List[Float64] = [1.0, 0.0]
    var marker_x: List[Float64] = [0.5]
    var marker_y: List[Float64] = [0.5]
    var figure = Figure()
    figure.line(xs, rising)
    figure.scatter(marker_x, marker_y)
    figure.line(xs, falling)

    var svg = render_svg(figure, 120.0, 80.0, fixture_margins())
    var first_line = first_occurrence(svg, "<polyline ")
    var marker = first_occurrence(svg, "<circle ")
    var second_line = first_occurrence(svg, "<polyline ", first_line + 1)

    assert_true(first_line >= 0)
    assert_true(first_line < marker)
    assert_true(marker < second_line)


def test_title_and_axis_labels_are_escaped_and_use_fixed_geometry() raises:
    var figure = titled_labels_figure()
    var svg = render_svg(figure, 120.0, 80.0, fixture_margins())

    assert_equal(count_occurrences(svg, ">Deterministic &lt;plot&gt;</text>"), 1)
    assert_equal(count_occurrences(svg, ">x &amp; time</text>"), 1)
    assert_equal(count_occurrences(svg, ">value &apos;y&apos;</text>"), 1)
    assert_equal(count_occurrences(svg, 'font-size="12" text-anchor="middle"'), 1)
    assert_equal(count_occurrences(svg, 'font-size="10" text-anchor="middle"'), 2)
    assert_equal(count_occurrences(svg, 'transform="rotate(-90 '), 1)


def test_default_render_size_is_640_by_480() raises:
    var figure = single_line_figure()
    var svg = render_svg(figure)

    assert_true(
        svg.startswith(
            '<svg xmlns="http://www.w3.org/2000/svg" width="640" height="480"'
        )
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
