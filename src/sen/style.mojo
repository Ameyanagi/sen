"""Renderer-independent series styling and fixed palette semantics."""

from std.math import isfinite


struct LineStyle(Copyable, Equatable, ImplicitlyCopyable):
    """A nominal line pattern with non-raising constants and equality."""

    var _value: Int

    comptime SOLID = LineStyle(_value=0)
    comptime DASHED = LineStyle(_value=1)
    comptime DOTTED = LineStyle(_value=2)
    comptime DASH_DOT = LineStyle(_value=3)

    def __init__(out self, *, _value: Int):
        """Construct a line-style discriminant for library-defined constants."""
        self._value = _value

    def __eq__(self, other: Self) -> Bool:
        """Return whether two line styles have the same discriminant."""
        return self._value == other._value

    def validate(self) raises:
        """Reject discriminants outside Sen's fixed line-style vocabulary."""
        if self._value < 0 or self._value > 3:
            raise Error("line style is outside Sen's vocabulary")


struct MarkerStyle(Copyable, Equatable, ImplicitlyCopyable):
    """A nominal marker with non-raising constants and equality."""

    var _value: Int

    comptime NONE = MarkerStyle(_value=0)
    comptime CIRCLE = MarkerStyle(_value=1)
    comptime SQUARE = MarkerStyle(_value=2)
    comptime TRIANGLE = MarkerStyle(_value=3)
    comptime DIAMOND = MarkerStyle(_value=4)
    comptime PLUS = MarkerStyle(_value=5)
    comptime CROSS = MarkerStyle(_value=6)
    comptime STAR = MarkerStyle(_value=7)

    def __init__(out self, *, _value: Int):
        """Construct a marker-style discriminant for library-defined constants."""
        self._value = _value

    def __eq__(self, other: Self) -> Bool:
        """Return whether two marker styles have the same discriminant."""
        return self._value == other._value

    def validate(self) raises:
        """Reject discriminants outside Sen's fixed marker vocabulary."""
        if self._value < 0 or self._value > 7:
            raise Error("marker style is outside Sen's vocabulary")


struct LineCap(Copyable, Equatable, ImplicitlyCopyable):
    """A nominal line-end treatment with fixed validated constants."""

    var _value: Int

    comptime BUTT = LineCap(_value=0)
    comptime ROUND = LineCap(_value=1)
    comptime SQUARE = LineCap(_value=2)

    def __init__(out self, *, _value: Int):
        """Construct a line-cap discriminant for library-defined constants."""
        self._value = _value

    def __eq__(self, other: Self) -> Bool:
        """Return whether two line caps have the same discriminant."""
        return self._value == other._value

    def validate(self) raises:
        """Reject discriminants outside Sen's fixed line-cap vocabulary."""
        if self._value < 0 or self._value > 2:
            raise Error("line cap is outside Sen's vocabulary")


struct LineJoin(Copyable, Equatable, ImplicitlyCopyable):
    """A nominal line-corner treatment with fixed validated constants."""

    var _value: Int

    comptime MITER = LineJoin(_value=0)
    comptime ROUND = LineJoin(_value=1)
    comptime BEVEL = LineJoin(_value=2)

    def __init__(out self, *, _value: Int):
        """Construct a line-join discriminant for library-defined constants."""
        self._value = _value

    def __eq__(self, other: Self) -> Bool:
        """Return whether two line joins have the same discriminant."""
        return self._value == other._value

    def validate(self) raises:
        """Reject discriminants outside Sen's fixed line-join vocabulary."""
        if self._value < 0 or self._value > 2:
            raise Error("line join is outside Sen's vocabulary")


def _parse_hex_color(
    color: StringSlice, role: StringSlice = "series color"
) raises -> String:
    """Validate and lowercase a strict six-digit hexadecimal color."""
    var valid = color.byte_length() == 7
    if valid:
        valid = color[byte=:1] == "#"
    if valid:
        for index in range(1, 7):
            var value = ord(color[byte=index])
            if not (
                (value >= ord("0") and value <= ord("9"))
                or (value >= ord("a") and value <= ord("f"))
                or (value >= ord("A") and value <= ord("F"))
            ):
                valid = False
                break
    if not valid:
        raise Error(
            role,
            (
                " must be '#' followed by exactly six hexadecimal digits, like "
                "'#1f77b4'; got '"
            ),
            color,
            "'",
        )
    return String(color).lower()


struct SeriesStyle(Copyable, Equatable, ImplicitlyCopyable):
    """Constructor-validated visual styling for one plotted series.

    A palette slot of ``-1`` requests render-time automatic assignment. Direct
    mutation of underscore-prefixed storage is out of contract; call
    ``validate`` explicitly when a checkpoint is needed. Automatic assignment
    deterministically walks insertion order and cycles through the first six
    Tableau-10 colors. Explicit palette slots and custom colors never advance
    that counter; a custom color takes precedence over either palette mode.
    """

    var _palette_slot: Int
    var _custom_color: String
    var _line_style: LineStyle
    var _marker_style: MarkerStyle
    var _line_width: Float64
    var _marker_size: Float64
    var _opacity: Float64
    var _line_cap: LineCap
    var _line_join: LineJoin

    def __init__(out self):
        """Construct deterministic automatic defaults without raising."""
        self._palette_slot = -1
        self._custom_color = String()
        self._line_style = LineStyle.SOLID
        self._marker_style = MarkerStyle.CIRCLE
        self._line_width = 1.5
        self._marker_size = 6.0
        self._opacity = 1.0
        self._line_cap = LineCap.ROUND
        self._line_join = LineJoin.ROUND

    def __init__(out self, *, color_index: Int) raises:
        """Construct an explicit palette style.

        Raises when ``color_index`` is outside the inclusive range 0 through 5.
        Valid construction deterministically uses the selected Tableau-10 slot,
        a solid line, circle marker, and width 1.5.
        """
        if color_index < 0 or color_index > 5:
            raise Error(
                "series color index ",
                color_index,
                " is outside the valid range 0..5",
            )
        self._palette_slot = color_index
        self._custom_color = String()
        self._line_style = LineStyle.SOLID
        self._marker_style = MarkerStyle.CIRCLE
        self._line_width = 1.5
        self._marker_size = 6.0
        self._opacity = 1.0
        self._line_cap = LineCap.ROUND
        self._line_join = LineJoin.ROUND

    def __init__(out self, *, color: StringSlice) raises:
        """Construct a style with a normalized custom hexadecimal color."""
        self._palette_slot = -1
        self._custom_color = _parse_hex_color(color)
        self._line_style = LineStyle.SOLID
        self._marker_style = MarkerStyle.CIRCLE
        self._line_width = 1.5
        self._marker_size = 6.0
        self._opacity = 1.0
        self._line_cap = LineCap.ROUND
        self._line_join = LineJoin.ROUND

    def with_line_width(self, width: Float64) raises -> Self:
        """Return a copy with ``width`` in points without changing the receiver.

        Raises when ``width`` is non-finite or not strictly positive.
        The remaining style fields are copied exactly and deterministically.
        """
        if not isfinite(width) or width <= 0.0:
            raise Error("series line width must be finite and positive; got ", width)
        var result = self.copy()
        result._line_width = width
        return result^

    def with_marker_size(self, size: Float64) raises -> Self:
        """Return a copy with marker ``size`` in points.

        Raises when ``size`` is non-finite or not strictly positive.
        """
        if not isfinite(size) or size <= 0.0:
            raise Error("series marker size must be finite and positive; got ", size)
        var result = self.copy()
        result._marker_size = size
        return result^

    def with_opacity(self, opacity: Float64) raises -> Self:
        """Return a copy with an opacity in the inclusive range zero to one."""
        if not isfinite(opacity) or opacity < 0.0 or opacity > 1.0:
            raise Error(
                "series opacity must be finite and in the range 0..1; got ",
                opacity,
            )
        var result = self.copy()
        result._opacity = opacity
        return result^

    def with_color(self, color: StringSlice) raises -> Self:
        """Return a copy with a normalized custom hexadecimal color.

        The custom color takes precedence over any stored explicit palette slot.
        """
        var result = self.copy()
        result._custom_color = _parse_hex_color(color)
        return result^

    def with_line_style(self, line_style: LineStyle) -> Self:
        """Return a deterministic copy with ``line_style``; this never raises."""
        var result = self.copy()
        result._line_style = line_style
        return result^

    def with_marker_style(self, marker: MarkerStyle) -> Self:
        """Return a deterministic copy with ``marker``; this never raises."""
        var result = self.copy()
        result._marker_style = marker
        return result^

    def with_line_cap(self, line_cap: LineCap) -> Self:
        """Return a deterministic copy with ``line_cap``; this never raises."""
        var result = self.copy()
        result._line_cap = line_cap
        return result^

    def with_line_join(self, line_join: LineJoin) -> Self:
        """Return a deterministic copy with ``line_join``; this never raises."""
        var result = self.copy()
        result._line_join = line_join
        return result^

    def validate(self) raises:
        """Validate every stored style field in deterministic order.

        Raises when the slot is outside ``-1..5``, a point size is invalid,
        opacity is outside ``0..1``, a nonempty custom color is not strict hex,
        or a nominal style is outside Sen's fixed vocabulary.
        """
        if self._palette_slot < -1 or self._palette_slot > 5:
            raise Error(
                "series palette slot ",
                self._palette_slot,
                " is outside the valid range -1..5",
            )
        if not isfinite(self._line_width) or self._line_width <= 0.0:
            raise Error(
                "series line width must be finite and positive; got ",
                self._line_width,
            )
        if not isfinite(self._marker_size) or self._marker_size <= 0.0:
            raise Error(
                "series marker size must be finite and positive; got ",
                self._marker_size,
            )
        if not isfinite(self._opacity) or self._opacity < 0.0 or self._opacity > 1.0:
            raise Error(
                "series opacity must be finite and in the range 0..1; got ",
                self._opacity,
            )
        if self._custom_color.byte_length() > 0:
            _ = _parse_hex_color(self._custom_color)
        self._line_style.validate()
        self._marker_style.validate()
        self._line_cap.validate()
        self._line_join.validate()

    def palette_slot(self) -> Int:
        """Return deterministic ``-1`` or an explicit slot without raising."""
        return self._palette_slot

    def color(self) -> String:
        """Return the normalized custom color, or empty for palette assignment."""
        return self._custom_color.copy()

    def line_style(self) -> LineStyle:
        """Return the exact line pattern without raising."""
        return self._line_style

    def marker_style(self) -> MarkerStyle:
        """Return the exact marker request without raising."""
        return self._marker_style

    def line_width(self) -> Float64:
        """Return the validated positive line width in points."""
        return self._line_width

    def marker_size(self) -> Float64:
        """Return the validated positive marker size in points."""
        return self._marker_size

    def opacity(self) -> Float64:
        """Return the validated series opacity without raising."""
        return self._opacity

    def line_cap(self) -> LineCap:
        """Return the exact line-end treatment without raising."""
        return self._line_cap

    def line_join(self) -> LineJoin:
        """Return the exact line-corner treatment without raising."""
        return self._line_join

    def __eq__(self, other: Self) -> Bool:
        """Return exact deterministic field equality without raising."""
        return (
            self._palette_slot == other._palette_slot
            and self._custom_color == other._custom_color
            and self._line_style == other._line_style
            and self._marker_style == other._marker_style
            and self._line_width == other._line_width
            and self._marker_size == other._marker_size
            and self._opacity == other._opacity
            and self._line_cap == other._line_cap
            and self._line_join == other._line_join
        )


def _palette_color(slot: Int) -> String:
    if slot == 0:
        return String("#1f77b4")
    if slot == 1:
        return String("#ff7f0e")
    if slot == 2:
        return String("#2ca02c")
    if slot == 3:
        return String("#d62728")
    if slot == 4:
        return String("#9467bd")
    return String("#8c564b")
