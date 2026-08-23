from sen.text import Text, TextKind
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
    assert_true,
)


def test_text_kind_is_nominal_and_validates_its_fixed_vocabulary() raises:
    assert_true(TextKind.PLAIN == TextKind.PLAIN)
    assert_true(TextKind.TYPST_MATH == TextKind.TYPST_MATH)
    assert_false(TextKind.PLAIN == TextKind.TYPST_MATH)

    TextKind.PLAIN.validate()
    TextKind.TYPST_MATH.validate()
    with assert_raises(contains="text kind is outside Sen's vocabulary"):
        TextKind(_value=-1).validate()
    with assert_raises(contains="text kind is outside Sen's vocabulary"):
        TextKind(_value=2).validate()


def test_plain_text_preserves_exact_cjk_and_whitespace() raises:
    var source = String("  日本語と한글\n中文  ")
    var text = Text.plain(source)

    assert_true(text.kind() == TextKind.PLAIN)
    assert_equal(text.source(), source)
    text.validate()


def test_typst_math_is_explicit_and_preserves_source_without_parsing() raises:
    var text = Text.typst_math("$ integral_0^infinity e^(-x^2) dif x $")

    assert_true(text.kind() == TextKind.TYPST_MATH)
    assert_equal(text.source(), "$ integral_0^infinity e^(-x^2) dif x $")
    text.validate()


def test_text_equality_includes_kind_and_exact_source() raises:
    assert_true(Text.plain("速度") == Text.plain("速度"))
    assert_false(Text.plain("速度") == Text.plain("速度 "))
    assert_false(Text.plain("x") == Text.typst_math("x"))


def test_text_validation_checks_embedded_kind() raises:
    var text = Text.plain("x")
    text._kind = TextKind(_value=2)

    with assert_raises(contains="text kind is outside Sen's vocabulary"):
        text.validate()


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
