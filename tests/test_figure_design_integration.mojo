from sen.figure_config import FigureConfig
from sen.series import Figure
from sen.theme import Theme, Typography
from std.testing import TestSuite, assert_equal, assert_raises, assert_true


def test_figure_has_deterministic_config_and_theme_defaults() raises:
    var figure = Figure()

    assert_true(figure.config() == FigureConfig())
    assert_true(figure.theme() == Theme())
    assert_true(figure.config().logical_width() == 640.0)
    assert_true(figure.config().logical_height() == 480.0)
    assert_equal(figure.config().raster_width(), 640)
    assert_equal(figure.config().raster_height(), 480)


def test_figure_size_and_dpi_are_independent() raises:
    var figure = Figure()

    figure.set_size(8.0, 4.5)
    assert_true(figure.config().width() == 8.0)
    assert_true(figure.config().height() == 4.5)
    assert_true(figure.config().dpi() == 100.0)

    figure.set_dpi(200.0)
    assert_true(figure.config().width() == 8.0)
    assert_true(figure.config().height() == 4.5)
    assert_true(figure.config().dpi() == 200.0)
    assert_equal(figure.config().raster_width(), 1600)
    assert_equal(figure.config().raster_height(), 900)
    assert_true(figure.config().logical_width() == 800.0)
    assert_true(figure.config().logical_height() == 450.0)


def test_figure_pixel_size_uses_current_dpi_without_changing_it() raises:
    var figure = Figure()
    figure.set_dpi(200.0)

    figure.set_size_px(1200, 800)

    assert_true(figure.config().width() == 6.0)
    assert_true(figure.config().height() == 4.0)
    assert_true(figure.config().dpi() == 200.0)
    assert_equal(figure.config().raster_width(), 1200)
    assert_equal(figure.config().raster_height(), 800)


def test_figure_replaces_config_and_theme_by_value() raises:
    var figure = Figure()
    var config = FigureConfig(7.0, 5.0, dpi=144.0)
    var typography = Typography().with_title_size(18.0)
    var theme = Theme.dark().with_typography(typography)

    figure.set_config(config)
    figure.set_theme(theme)

    assert_true(figure.config() == config)
    assert_true(figure.theme() == theme)
    assert_true(figure.theme().typography().title_size() == 18.0)

    config._width = 1.0
    theme._background = String("#000000")
    assert_true(figure.config().width() == 7.0)
    assert_equal(figure.theme().background(), "#111827")


def test_figure_setters_reject_invalid_values_atomically() raises:
    var figure = Figure()
    var original = figure.config()
    var original_theme = figure.theme()

    with assert_raises(contains="figure physical size must be positive"):
        figure.set_size(0.0, 4.0)
    assert_true(figure.config() == original)

    with assert_raises(contains="figure pixel size must be positive"):
        figure.set_size_px(-1, 480)
    assert_true(figure.config() == original)

    with assert_raises(contains="figure export DPI must be positive"):
        figure.set_dpi(0.0)
    assert_true(figure.config() == original)

    var invalid_config = FigureConfig()
    invalid_config._dpi = 0.0
    with assert_raises(contains="figure export DPI must be positive"):
        figure.set_config(invalid_config)
    assert_true(figure.config() == original)

    var invalid_theme = Theme()
    invalid_theme._typography._family = String(" ")
    with assert_raises(contains="typography font family must not be empty"):
        figure.set_theme(invalid_theme)
    assert_true(figure.theme() == original_theme)


def test_figure_validation_checks_config_and_theme() raises:
    var invalid_config = Figure()
    invalid_config._config._dpi = 0.0
    with assert_raises(contains="figure export DPI must be positive"):
        invalid_config.validate()

    var invalid_theme = Figure()
    invalid_theme._theme._typography._family = String("  ")
    with assert_raises(contains="typography font family must not be empty"):
        invalid_theme.validate()


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
