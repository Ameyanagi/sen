from sen import Plot
from sen.theme import Theme
from std.testing import TestSuite, assert_raises, assert_true


def test_plot_imperative_design_config_forwards_to_figure() raises:
    var plot = Plot()

    plot.size(8.0, 5.0)
    plot.dpi(144.0)
    plot.theme(Theme.dark())

    var config = plot.figure().config()
    assert_true(config.width() == 8.0)
    assert_true(config.height() == 5.0)
    assert_true(config.dpi() == 144.0)
    assert_true(config.logical_width() == 800.0)
    assert_true(config.logical_height() == 500.0)
    assert_true(config.raster_width() == 1152)
    assert_true(config.raster_height() == 720)
    assert_true(plot.figure().theme() == Theme.dark())


def test_plot_pixel_size_uses_current_dpi_without_changing_it() raises:
    var plot = Plot()
    plot.dpi(144.0)
    plot.size_px(720, 360)

    var config = plot.figure().config()
    assert_true(config.width() == 5.0)
    assert_true(config.height() == 2.5)
    assert_true(config.dpi() == 144.0)
    assert_true(config.raster_width() == 720)
    assert_true(config.raster_height() == 360)

    var fluent = Plot().with_dpi(144.0).with_size_px(720, 360)
    assert_true(fluent.figure().config() == config)


def test_plot_design_config_builders_chain_and_persist() raises:
    var plot = (
        Plot()
        .with_size(7.0, 4.0)
        .with_dpi(200.0)
        .with_theme(Theme.dark())
        .with_title("Configured")
    )

    var config = plot.figure().config()
    assert_true(config.width() == 7.0)
    assert_true(config.height() == 4.0)
    assert_true(config.dpi() == 200.0)
    assert_true(config.logical_width() == 700.0)
    assert_true(config.logical_height() == 400.0)
    assert_true(config.raster_width() == 1400)
    assert_true(config.raster_height() == 800)
    assert_true(plot.figure().theme() == Theme.dark())
    assert_true(plot.figure().title() == "Configured")


def test_plot_design_config_preserves_figure_validation() raises:
    with assert_raises(contains="physical size must be positive"):
        _ = Plot().with_size(0.0, 4.0)
    with assert_raises(contains="pixel size must be positive"):
        _ = Plot().with_size_px(640, 0)
    with assert_raises(contains="export DPI must be positive"):
        _ = Plot().with_dpi(0.0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
