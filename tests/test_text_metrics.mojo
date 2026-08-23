from sen.text_metrics import text_height, text_width
from std.testing import TestSuite, assert_almost_equal, assert_raises


def _assert_width(text: StringSlice, ems: Float64) raises:
    assert_almost_equal(text_width(text, 10.0), ems * 10.0, atol=1e-12)


def test_empty_and_ascii_widths_are_deterministic() raises:
    _assert_width("", 0.0)
    _assert_width(" ", 0.33)
    _assert_width("i.,", 1.05)
    _assert_width("abc", 1.68)
    _assert_width("MW", 1.6)


def test_cjk_scripts_and_wide_punctuation_use_one_em_per_cluster() raises:
    _assert_width("日本語", 3.0)
    _assert_width("汉字", 2.0)
    _assert_width("漢字", 2.0)
    _assert_width("かなカナ", 4.0)
    _assert_width("ㄅㄆ", 2.0)
    _assert_width("한글", 2.0)
    _assert_width("，。", 2.0)
    _assert_width(chr(0x323B0), 1.0)


def test_decomposed_cjk_and_latin_are_measured_as_graphemes() raises:
    var decomposed_hangul = String(chr(0x1112), chr(0x1161), chr(0x11AB))
    var decomposed_latin = String("e", chr(0x0301))

    _assert_width(decomposed_hangul, 1.0)
    _assert_width("é", 0.56)
    _assert_width(decomposed_latin, 0.56)


def test_non_rendering_clusters_have_zero_width() raises:
    _assert_width(chr(0x0301), 0.0)
    _assert_width(chr(0x0007), 0.0)
    _assert_width(chr(0x0085), 0.0)
    _assert_width(chr(0x200B), 0.0)
    _assert_width(chr(0x2060), 0.0)
    _assert_width(chr(0xFE0F), 0.0)


def test_emoji_sequences_and_flags_each_use_one_em() raises:
    _assert_width("😀", 1.0)
    _assert_width("👩‍🔬", 1.0)
    _assert_width("🇯🇵", 1.0)
    _assert_width("👍🏽", 1.0)


def test_mixed_text_sums_cluster_factors() raises:
    _assert_width("A 日本", 2.89)
    _assert_width("Mé👩‍🔬漢", 3.36)


def test_text_height_uses_a_readable_line_box() raises:
    assert_almost_equal(text_height(10.0), 12.0, atol=1e-12)
    assert_almost_equal(text_height(16.0), 19.2, atol=1e-12)


def test_metrics_reject_non_positive_and_non_finite_font_sizes() raises:
    with assert_raises(contains="font size must be finite and positive"):
        _ = text_width("text", 0.0)
    with assert_raises(contains="font size must be finite and positive"):
        _ = text_width("text", -1.0)
    with assert_raises(contains="font size must be finite and positive"):
        _ = text_width("text", Float64("nan"))
    with assert_raises(contains="font size must be finite and positive"):
        _ = text_height(Float64("inf"))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
