"""Renderer-independent series styling and fixed palette semantics."""

from std.math import isfinite


struct LineStyle(Copyable, Equatable, ImplicitlyCopyable):
    """A non-raising nominal line pattern with deterministic SVG dash geometry."""

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


struct MarkerStyle(Copyable, Equatable, ImplicitlyCopyable):
    """A non-raising nominal marker with deterministic fixed SVG geometry."""

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


struct SeriesStyle(Copyable, Equatable, ImplicitlyCopyable):
    """Constructor-validated visual styling for one plotted series.

    A palette slot of ``-1`` requests render-time automatic assignment. Direct
    mutation of underscore-prefixed storage is out of contract; call
    ``validate`` explicitly when a checkpoint is needed. Automatic assignment
    deterministically walks insertion order and cycles through the first six
    Tableau-10 colors; explicit slots never advance that counter.
    """

    var _palette_slot: Int
    var _line_style: LineStyle
    var _marker_style: MarkerStyle
    var _line_width: Float64

    def __init__(out self):
        """Construct deterministic automatic defaults without raising."""
        self._palette_slot = -1
        self._line_style = LineStyle.SOLID
        self._marker_style = MarkerStyle.CIRCLE
        self._line_width = 1.5

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
        self._line_style = LineStyle.SOLID
        self._marker_style = MarkerStyle.CIRCLE
        self._line_width = 1.5

    def with_width(self, width: Float64) raises -> Self:
        """Return a copy with ``width`` without changing the receiver.

        Raises when ``width`` is non-finite or not strictly positive.
        The remaining style fields are copied exactly and deterministically.
        """
        if not isfinite(width) or width <= 0.0:
            raise Error("series line width must be finite and positive; got ", width)
        var result = self.copy()
        result._line_width = width
        return result^

    def with_line_style(self, line_style: LineStyle) -> Self:
        """Return a deterministic copy with ``line_style``; this never raises."""
        var result = self.copy()
        result._line_style = line_style
        return result^

    def with_marker(self, marker: MarkerStyle) -> Self:
        """Return a deterministic copy with ``marker``; this never raises."""
        var result = self.copy()
        result._marker_style = marker
        return result^

    def validate(self) raises:
        """Validate the stored palette slot and line width explicitly.

        Raises when the slot is outside ``-1..5`` or the width is non-finite or
        not strictly positive. Checks run in stable palette-then-width order.
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

    def palette_slot(self) -> Int:
        """Return deterministic ``-1`` or an explicit slot without raising."""
        return self._palette_slot

    def line_style(self) -> LineStyle:
        """Return the exact line pattern without raising."""
        return self._line_style

    def marker_style(self) -> MarkerStyle:
        """Return the exact marker request without raising."""
        return self._marker_style

    def line_width(self) -> Float64:
        """Return the validated positive width without raising."""
        return self._line_width

    def __eq__(self, other: Self) -> Bool:
        """Return exact deterministic field equality without raising."""
        return (
            self._palette_slot == other._palette_slot
            and self._line_style == other._line_style
            and self._marker_style == other._marker_style
            and self._line_width == other._line_width
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
