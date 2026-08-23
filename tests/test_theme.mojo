from sen import TextLocale
from sen.theme import Theme, Typography
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
    assert_true,
)


def test_typography_defaults_include_cjk_fallbacks_and_semantic_sizes() raises:
    var typography = Typography()

    assert_true("Noto Sans CJK JP" in typography.family())
    assert_true("Noto Sans CJK SC" in typography.family())
    assert_true("Noto Sans CJK TC" in typography.family())
    assert_true("Noto Sans CJK KR" in typography.family())
    assert_true("Hiragino Sans" in typography.family())
    assert_true("Yu Gothic" in typography.family())
    assert_true("PingFang SC" in typography.family())
    assert_true("Microsoft YaHei" in typography.family())
    assert_true("Malgun Gothic" in typography.family())
    assert_true(typography.title_size() == 14.0)
    assert_true(typography.axis_size() == 10.0)
    assert_true(typography.tick_size() == 9.0)
    assert_true(typography.legend_size() == 9.0)
    assert_true(typography == Typography())


def test_text_locale_has_validated_svg_language_tags() raises:
    assert_equal(TextLocale.AUTO.language_tag(), "")
    assert_equal(TextLocale.JA.language_tag(), "ja")
    assert_equal(TextLocale.ZH_HANS.language_tag(), "zh-Hans")
    assert_equal(TextLocale.ZH_HANT.language_tag(), "zh-Hant")
    assert_equal(TextLocale.KO.language_tag(), "ko")

    TextLocale.AUTO.validate()
    TextLocale.JA.validate()
    TextLocale.ZH_HANS.validate()
    TextLocale.ZH_HANT.validate()
    TextLocale.KO.validate()

    with assert_raises(contains="text locale is outside Sen's vocabulary"):
        TextLocale(_value=5).validate()


def test_typography_locale_selects_cjk_and_emoji_fallback_order() raises:
    var automatic = Typography()
    var ja = automatic.with_locale(TextLocale.JA)
    var zh_hans = automatic.with_locale(TextLocale.ZH_HANS)
    var zh_hant = automatic.with_locale(TextLocale.ZH_HANT)
    var ko = automatic.with_locale(TextLocale.KO)

    assert_true(automatic.locale() == TextLocale.AUTO)
    assert_true(ja.locale() == TextLocale.JA)
    assert_true(zh_hans.locale() == TextLocale.ZH_HANS)
    assert_true(zh_hant.locale() == TextLocale.ZH_HANT)
    assert_true(ko.locale() == TextLocale.KO)
    assert_true(ja.family().startswith("Inter, system-ui, -apple-system"))
    assert_true('"Noto Sans CJK JP", "Noto Sans JP"' in ja.family())
    assert_true('"Noto Sans CJK SC", "Noto Sans SC"' in zh_hans.family())
    assert_true('"Noto Sans CJK TC", "Noto Sans TC"' in zh_hant.family())
    assert_true('"Noto Sans CJK KR", "Noto Sans KR"' in ko.family())
    assert_true('"Apple Color Emoji"' in ja.family())
    assert_true('"Segoe UI Emoji"' in zh_hans.family())
    assert_true('"Noto Color Emoji", sans-serif' in ko.family())
    assert_false(ja == zh_hans)


def test_typography_custom_family_preserves_locale_and_chain_order_is_explicit() raises:
    var custom = (
        Typography()
        .with_locale(TextLocale.ZH_HANT)
        .with_family('"Project Sans TC", sans-serif')
    )
    assert_true(custom.locale() == TextLocale.ZH_HANT)
    assert_equal(custom.family(), '"Project Sans TC", sans-serif')

    var reset_to_locale_defaults = custom.with_locale(TextLocale.KO)
    assert_true(reset_to_locale_defaults.locale() == TextLocale.KO)
    assert_true(
        '"Noto Sans CJK KR", "Noto Sans KR"' in reset_to_locale_defaults.family()
    )
    assert_false(reset_to_locale_defaults.family() == custom.family())


def test_typography_rejects_corrupted_locale() raises:
    var typography = Typography()
    typography._locale = TextLocale(_value=99)
    with assert_raises(contains="text locale is outside Sen's vocabulary"):
        typography.validate()


def test_typography_builders_are_chainable_and_leave_original_unchanged() raises:
    var original = Typography()
    var customized = (
        original.with_family('"Noto Sans CJK SC", sans-serif')
        .with_title_size(18.0)
        .with_axis_size(12.0)
        .with_tick_size(10.0)
        .with_legend_size(11.0)
    )

    assert_false(original == customized)
    assert_true(original.title_size() == 14.0)
    assert_equal(customized.family(), '"Noto Sans CJK SC", sans-serif')
    assert_true(customized.title_size() == 18.0)
    assert_true(customized.axis_size() == 12.0)
    assert_true(customized.tick_size() == 10.0)
    assert_true(customized.legend_size() == 11.0)
    assert_true(
        customized
        == Typography(
            '"Noto Sans CJK SC", sans-serif',
            title_size=18.0,
            axis_size=12.0,
            tick_size=10.0,
            legend_size=11.0,
        )
    )


def test_typography_rejects_blank_family_and_invalid_sizes() raises:
    with assert_raises(contains="font family must not be empty or blank"):
        _ = Typography("   ")
    with assert_raises(contains="title size must be finite and positive"):
        _ = Typography().with_title_size(0.0)
    with assert_raises(contains="axis size must be finite and positive"):
        _ = Typography().with_axis_size(-1.0)
    with assert_raises(contains="tick size must be finite and positive"):
        _ = Typography().with_tick_size(Float64("nan"))
    with assert_raises(contains="legend size must be finite and positive"):
        _ = Typography().with_legend_size(Float64("inf"))


def test_light_and_dark_theme_defaults_are_deterministic() raises:
    var light = Theme()
    var dark = Theme.dark()

    assert_equal(light.background(), "#ffffff")
    assert_equal(light.foreground(), "#202124")
    assert_equal(light.grid(), "#d9dee7")
    assert_equal(light.frame(), "#7a8494")
    assert_equal(light.legend_background(), "#ffffff")
    assert_equal(dark.background(), "#111827")
    assert_equal(dark.foreground(), "#e5e7eb")
    assert_equal(dark.grid(), "#374151")
    assert_equal(dark.frame(), "#6b7280")
    assert_equal(dark.legend_background(), "#1f2937")
    assert_true(light == Theme())
    assert_true(dark == Theme.dark())
    assert_false(light == dark)


def test_theme_builders_normalize_colors_and_preserve_value_semantics() raises:
    var original = Theme()
    var typography = Typography().with_title_size(16.0)
    var customized = (
        original.with_typography(typography)
        .with_background("#ABCDEF")
        .with_foreground("#123456")
        .with_grid("#FEDCBA")
        .with_frame("#A0B1C2")
        .with_legend_background("#0A0B0C")
    )

    assert_equal(original.background(), "#ffffff")
    assert_true(original.typography().title_size() == 14.0)
    assert_true(customized.typography() == typography)
    assert_equal(customized.background(), "#abcdef")
    assert_equal(customized.foreground(), "#123456")
    assert_equal(customized.grid(), "#fedcba")
    assert_equal(customized.frame(), "#a0b1c2")
    assert_equal(customized.legend_background(), "#0a0b0c")


def test_theme_rejects_invalid_colors_and_corrupted_typography() raises:
    with assert_raises(contains="theme background must be '#' followed"):
        _ = Theme().with_background("white")
    with assert_raises(contains="theme grid must be '#' followed"):
        _ = Theme().with_grid("#12345g")

    var broken_typography = Typography()
    broken_typography._axis_size = 0.0
    with assert_raises(contains="axis size must be finite and positive"):
        _ = Theme().with_typography(broken_typography)

    var broken_theme = Theme()
    broken_theme._frame = String("#bad")
    with assert_raises(contains="theme frame must be '#' followed"):
        broken_theme.validate()


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
