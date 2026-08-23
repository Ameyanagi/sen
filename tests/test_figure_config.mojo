from sen.figure_config import FigureConfig
from std.testing import TestSuite, assert_raises, assert_true


def test_default_size_has_independent_logical_and_raster_dimensions() raises:
    var config = FigureConfig()

    assert_true(config.width() == 6.4)
    assert_true(config.height() == 4.8)
    assert_true(config.dpi() == 100.0)
    assert_true(config.logical_width() == 640.0)
    assert_true(config.logical_height() == 480.0)
    assert_true(config.raster_width() == 640)
    assert_true(config.raster_height() == 480)
    assert_true(config == FigureConfig(6.4, 4.8, dpi=100.0))


def test_dpi_changes_raster_extent_without_changing_physical_or_logical_size() raises:
    var original = FigureConfig()
    var retina = original.with_dpi(200.0)

    assert_true(original.dpi() == 100.0)
    assert_true(retina.dpi() == 200.0)
    assert_true(retina.width() == original.width())
    assert_true(retina.height() == original.height())
    assert_true(retina.logical_width() == original.logical_width())
    assert_true(retina.logical_height() == original.logical_height())
    assert_true(retina.raster_width() == 1280)
    assert_true(retina.raster_height() == 960)


def test_physical_and_pixel_size_builders_preserve_current_dpi() raises:
    var original = FigureConfig().with_dpi(144.0)
    var physical = original.with_size(8.0, 5.0)
    var pixels = original.with_size_px(720, 360)

    assert_true(original.width() == 6.4)
    assert_true(physical.width() == 8.0)
    assert_true(physical.height() == 5.0)
    assert_true(physical.dpi() == 144.0)
    assert_true(physical.raster_width() == 1152)
    assert_true(physical.raster_height() == 720)
    assert_true(pixels.width() == 5.0)
    assert_true(pixels.height() == 2.5)
    assert_true(pixels.dpi() == 144.0)
    assert_true(pixels.raster_width() == 720)
    assert_true(pixels.raster_height() == 360)


def test_raster_dimensions_use_deterministic_positive_half_up_rounding() raises:
    var below = FigureConfig(1.004, 1.004, dpi=100.0)

    assert_true(below.raster_width() == 100)
    assert_true(below.raster_height() == 100)
    assert_true(FigureConfig(2.5, 3.5, dpi=1.0).raster_width() == 3)
    assert_true(FigureConfig(2.5, 3.5, dpi=1.0).raster_height() == 4)


def test_figure_config_rejects_invalid_sizes_and_dpi() raises:
    with assert_raises(contains="physical size must be positive"):
        _ = FigureConfig(0.0, 4.8)
    with assert_raises(contains="physical size must be positive"):
        _ = FigureConfig(6.4, -1.0)
    with assert_raises(contains="physical size must be finite"):
        _ = FigureConfig(Float64("nan"), 4.8)
    with assert_raises(contains="pixel size must be positive"):
        _ = FigureConfig().with_size_px(0, 480)
    with assert_raises(contains="pixel size must be positive"):
        _ = FigureConfig().with_size_px(640, -1)
    with assert_raises(contains="export DPI must be positive"):
        _ = FigureConfig().with_dpi(0.0)
    with assert_raises(contains="export DPI must be finite"):
        _ = FigureConfig().with_dpi(Float64("nan"))
    with assert_raises(contains="round to at least one pixel per axis"):
        _ = FigureConfig(0.1, 0.1, dpi=1.0)
    with assert_raises(contains="logical size exceeds the SVG"):
        _ = FigureConfig(9.1e13, 4.8, dpi=1.0)


def test_explicit_validation_detects_corrupted_storage() raises:
    var config = FigureConfig()
    config._width = -1.0
    with assert_raises(contains="physical size must be positive"):
        config.validate()


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
