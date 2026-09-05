from sen import Plot, Figure, build_render_plan, encode_svg
from std.testing import TestSuite, assert_equal, assert_true, assert_raises


def _plot() raises -> Plot:
    var x: List[Float64] = [0.0, 1.0]
    var y: List[Float64] = [1.0, 2.0]
    return Plot().with_line(x, y).with_title("Calibration")


def test_description_survives_semantic_and_plan_boundaries() raises:
    var description = String("Input < 2 & response > 0; fit and measured series. 日本語")
    var plot = _plot().with_description(description.copy())
    assert_equal(plot.figure().accessible_description(), description)
    var plan = plot.build_render_plan()
    assert_equal(plan.accessible_description, description)
    var svg = encode_svg(plan)
    assert_true('role="img"' in svg)
    assert_true("<title>Calibration</title>" in svg)
    assert_true(
        "<desc>Input &lt; 2 &amp; response &gt; 0; fit and measured series. 日本語</desc>"
        in svg
    )
    var changed = plan.copy()
    changed.accessible_description = String("Other")
    assert_true(changed != plan)
    var figure = plot^.into_figure()
    assert_equal(figure.accessible_description(), description)
    figure.set_accessible_description(String())
    assert_true("<desc>Scientific plot rendered by Sen.</desc>" in figure.render_svg())


def test_description_rejects_xml_forbidden_scalars_at_encoding() raises:
    var plot = _plot().with_description(String("bad\x01description"))
    with assert_raises(contains="scalar forbidden by XML 1.0"):
        _ = plot.render_svg()
    var plan = _plot().build_render_plan()
    plan.accessible_description = String("bad\x00description")
    with assert_raises(contains="scalar forbidden by XML 1.0"):
        _ = encode_svg(plan)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
