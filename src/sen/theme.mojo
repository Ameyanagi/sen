"""Backend-independent typography and figure theme values."""

from std.math import isfinite

from .style import _parse_hex_color


struct TextLocale(Copyable, Equatable, ImplicitlyCopyable):
    """A nominal CJK language choice for glyph forms and font fallback order.

    ``AUTO`` leaves SVG language selection to the embedding document while
    retaining broad CJK coverage. The explicit values map to stable BCP 47
    language tags suitable for both SVG ``lang`` and ``xml:lang``.
    """

    var _value: Int

    comptime AUTO = TextLocale(_value=0)
    comptime JA = TextLocale(_value=1)
    comptime ZH_HANS = TextLocale(_value=2)
    comptime ZH_HANT = TextLocale(_value=3)
    comptime KO = TextLocale(_value=4)

    def __init__(out self, *, _value: Int):
        """Construct a locale discriminant for library-defined constants."""
        self._value = _value

    def __eq__(self, other: Self) -> Bool:
        """Return whether both values select the same locale."""
        return self._value == other._value

    def validate(self) raises:
        """Reject discriminants outside Sen's fixed locale vocabulary."""
        if self._value < 0 or self._value > 4:
            raise Error("text locale is outside Sen's vocabulary")

    def language_tag(self) -> String:
        """Return a BCP 47 tag, or an empty string when selection is automatic."""
        if self._value == 1:
            return String("ja")
        if self._value == 2:
            return String("zh-Hans")
        if self._value == 3:
            return String("zh-Hant")
        if self._value == 4:
            return String("ko")
        return String()


struct Typography(Copyable, Equatable, ImplicitlyCopyable):
    """A CJK-capable SVG font stack and point sizes by semantic role."""

    var _family: String
    var _locale: TextLocale
    var _title_size: Float64
    var _axis_size: Float64
    var _tick_size: Float64
    var _legend_size: Float64

    def __init__(out self):
        """Construct accessible defaults with broad system CJK fallbacks."""
        self._locale = TextLocale.AUTO
        self._family = Self._default_family(self._locale)
        self._title_size = 14.0
        self._axis_size = 10.0
        self._tick_size = 9.0
        self._legend_size = 9.0

    def __init__(
        out self,
        family: StringSlice,
        *,
        title_size: Float64 = 14.0,
        axis_size: Float64 = 10.0,
        tick_size: Float64 = 9.0,
        legend_size: Float64 = 9.0,
        locale: TextLocale = TextLocale.AUTO,
    ) raises:
        """Construct fully specified and validated typography."""
        self._family = String(family)
        self._locale = locale
        self._title_size = title_size
        self._axis_size = axis_size
        self._tick_size = tick_size
        self._legend_size = legend_size
        self.validate()

    def with_family(self, family: StringSlice) raises -> Self:
        """Return a copy with a nonblank font-family expression."""
        var result = self.copy()
        result._family = String(family)
        result.validate()
        return result^

    def with_locale(self, locale: TextLocale) raises -> Self:
        """Return a copy using the locale's complete default fallback stack.

        This deliberately replaces a custom family. Call ``with_family`` after
        ``with_locale`` when a project font should override locale defaults.
        """
        locale.validate()
        var result = self.copy()
        result._locale = locale
        result._family = Self._default_family(locale)
        return result^

    def with_title_size(self, size: Float64) raises -> Self:
        """Return a copy with a validated title point size."""
        var result = self.copy()
        result._title_size = size
        result.validate()
        return result^

    def with_axis_size(self, size: Float64) raises -> Self:
        """Return a copy with a validated axis-label point size."""
        var result = self.copy()
        result._axis_size = size
        result.validate()
        return result^

    def with_tick_size(self, size: Float64) raises -> Self:
        """Return a copy with a validated tick-label point size."""
        var result = self.copy()
        result._tick_size = size
        result.validate()
        return result^

    def with_legend_size(self, size: Float64) raises -> Self:
        """Return a copy with a validated legend point size."""
        var result = self.copy()
        result._legend_size = size
        result.validate()
        return result^

    def validate(self) raises:
        """Validate the font family and all role sizes in deterministic order."""
        self._locale.validate()
        if self._family.strip().byte_length() == 0:
            raise Error("typography font family must not be empty or blank")
        Self._validate_size("title", self._title_size)
        Self._validate_size("axis", self._axis_size)
        Self._validate_size("tick", self._tick_size)
        Self._validate_size("legend", self._legend_size)

    @staticmethod
    def _validate_size(role: StringSlice, size: Float64) raises:
        if not isfinite(size) or size <= 0.0:
            raise Error(
                "typography ", role, " size must be finite and positive; got ", size
            )

    @staticmethod
    def _default_family(locale: TextLocale) -> String:
        var latin = String(
            'Inter, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", '
            '"Noto Sans", '
        )
        var emoji = String(
            ', "Apple Color Emoji", "Segoe UI Emoji", "Noto Color Emoji", sans-serif'
        )
        if locale == TextLocale.JA:
            return (
                latin
                + '"Noto Sans CJK JP", "Noto Sans JP", "Hiragino Sans", '
                '"Yu Gothic", YuGothic, Meiryo, "Noto Sans CJK SC", '
                '"Noto Sans CJK TC", "Noto Sans CJK KR", "PingFang SC", '
                '"PingFang TC", "Microsoft YaHei", "Microsoft JhengHei", '
                '"Apple SD Gothic Neo", "Malgun Gothic"'
                + emoji
            )
        if locale == TextLocale.ZH_HANS:
            return (
                latin
                + '"Noto Sans CJK SC", "Noto Sans SC", "Source Han Sans CN", '
                '"PingFang SC", "Microsoft YaHei", "WenQuanYi Micro Hei", '
                'SimHei, "Noto Sans CJK TC", "Noto Sans CJK JP", '
                '"Noto Sans CJK KR", "PingFang TC", "Microsoft JhengHei", '
                '"Hiragino Sans", "Yu Gothic", Meiryo, '
                '"Apple SD Gothic Neo", "Malgun Gothic"'
                + emoji
            )
        if locale == TextLocale.ZH_HANT:
            return (
                latin
                + '"Noto Sans CJK TC", "Noto Sans TC", "Source Han Sans TW", '
                '"PingFang TC", "Microsoft JhengHei", "Heiti TC", '
                '"Noto Sans CJK SC", "Noto Sans CJK JP", '
                '"Noto Sans CJK KR", "PingFang SC", "Microsoft YaHei", '
                '"Hiragino Sans", "Yu Gothic", Meiryo, '
                '"Apple SD Gothic Neo", "Malgun Gothic"'
                + emoji
            )
        if locale == TextLocale.KO:
            return (
                latin
                + '"Noto Sans CJK KR", "Noto Sans KR", "Source Han Sans K", '
                '"Apple SD Gothic Neo", "Malgun Gothic", NanumGothic, '
                '"Noto Sans CJK JP", "Noto Sans CJK SC", '
                '"Noto Sans CJK TC", "Hiragino Sans", "Yu Gothic", Meiryo, '
                '"PingFang SC", "PingFang TC", "Microsoft YaHei", '
                '"Microsoft JhengHei"'
                + emoji
            )
        return (
            latin
            + '"Noto Sans CJK JP", "Noto Sans JP", "Noto Sans CJK SC", '
            '"Noto Sans SC", "Noto Sans CJK TC", "Noto Sans TC", '
            '"Noto Sans CJK KR", "Noto Sans KR", "Hiragino Sans", '
            '"Yu Gothic", YuGothic, Meiryo, "PingFang SC", "PingFang TC", '
            '"Microsoft YaHei", "Microsoft JhengHei", '
            '"Apple SD Gothic Neo", "Malgun Gothic", NanumGothic'
            + emoji
        )

    def family(self) -> String:
        """Return the SVG font-family fallback expression."""
        return self._family.copy()

    def locale(self) -> TextLocale:
        """Return the locale used for CJK glyph forms and fallback ordering."""
        return self._locale

    def title_size(self) -> Float64:
        """Return title point size."""
        return self._title_size

    def axis_size(self) -> Float64:
        """Return axis-label point size."""
        return self._axis_size

    def tick_size(self) -> Float64:
        """Return tick-label point size."""
        return self._tick_size

    def legend_size(self) -> Float64:
        """Return legend point size."""
        return self._legend_size

    def __eq__(self, other: Self) -> Bool:
        """Return exact equality of family and all semantic point sizes."""
        return (
            self._family == other._family
            and self._locale == other._locale
            and self._title_size == other._title_size
            and self._axis_size == other._axis_size
            and self._tick_size == other._tick_size
            and self._legend_size == other._legend_size
        )


struct Theme(Copyable, Equatable, ImplicitlyCopyable):
    """Typography and normalized colors shared by rendering backends."""

    var _typography: Typography
    var _background: String
    var _foreground: String
    var _grid: String
    var _frame: String
    var _legend_background: String

    def __init__(out self):
        """Construct Sen's light theme."""
        self._typography = Typography()
        self._background = String("#ffffff")
        self._foreground = String("#202124")
        self._grid = String("#d9dee7")
        self._frame = String("#7a8494")
        self._legend_background = String("#ffffff")

    def __init__(
        out self,
        typography: Typography,
        *,
        background: StringSlice,
        foreground: StringSlice,
        grid: StringSlice,
        frame: StringSlice,
        legend_background: StringSlice,
    ) raises:
        """Construct fully specified and validated theme values."""
        typography.validate()
        self._typography = typography
        self._background = _parse_hex_color(background, "theme background")
        self._foreground = _parse_hex_color(foreground, "theme foreground")
        self._grid = _parse_hex_color(grid, "theme grid")
        self._frame = _parse_hex_color(frame, "theme frame")
        self._legend_background = _parse_hex_color(
            legend_background, "theme legend background"
        )

    @staticmethod
    def dark() -> Self:
        """Return Sen's deterministic high-contrast dark theme."""
        var result = Self()
        result._background = String("#111827")
        result._foreground = String("#e5e7eb")
        result._grid = String("#374151")
        result._frame = String("#6b7280")
        result._legend_background = String("#1f2937")
        return result^

    def with_typography(self, typography: Typography) raises -> Self:
        """Return a copy with validated typography."""
        typography.validate()
        var result = self.copy()
        result._typography = typography
        return result^

    def with_background(self, color: StringSlice) raises -> Self:
        """Return a copy with a normalized background color."""
        var result = self.copy()
        result._background = _parse_hex_color(color, "theme background")
        return result^

    def with_foreground(self, color: StringSlice) raises -> Self:
        """Return a copy with a normalized foreground color."""
        var result = self.copy()
        result._foreground = _parse_hex_color(color, "theme foreground")
        return result^

    def with_grid(self, color: StringSlice) raises -> Self:
        """Return a copy with a normalized grid color."""
        var result = self.copy()
        result._grid = _parse_hex_color(color, "theme grid")
        return result^

    def with_frame(self, color: StringSlice) raises -> Self:
        """Return a copy with a normalized frame color."""
        var result = self.copy()
        result._frame = _parse_hex_color(color, "theme frame")
        return result^

    def with_legend_background(self, color: StringSlice) raises -> Self:
        """Return a copy with a normalized legend background color."""
        var result = self.copy()
        result._legend_background = _parse_hex_color(color, "theme legend background")
        return result^

    def validate(self) raises:
        """Validate embedded typography and every color in stable field order."""
        self._typography.validate()
        _ = _parse_hex_color(self._background, "theme background")
        _ = _parse_hex_color(self._foreground, "theme foreground")
        _ = _parse_hex_color(self._grid, "theme grid")
        _ = _parse_hex_color(self._frame, "theme frame")
        _ = _parse_hex_color(self._legend_background, "theme legend background")

    def typography(self) -> Typography:
        """Return typography by value."""
        return self._typography

    def background(self) -> String:
        """Return normalized background color."""
        return self._background.copy()

    def foreground(self) -> String:
        """Return normalized foreground color."""
        return self._foreground.copy()

    def grid(self) -> String:
        """Return normalized grid color."""
        return self._grid.copy()

    def frame(self) -> String:
        """Return normalized frame color."""
        return self._frame.copy()

    def legend_background(self) -> String:
        """Return normalized legend background color."""
        return self._legend_background.copy()

    def __eq__(self, other: Self) -> Bool:
        """Return exact equality of typography and normalized colors."""
        return (
            self._typography == other._typography
            and self._background == other._background
            and self._foreground == other._foreground
            and self._grid == other._grid
            and self._frame == other._frame
            and self._legend_background == other._legend_background
        )
