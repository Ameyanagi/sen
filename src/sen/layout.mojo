"""Backend-independent logical figure layout."""

from std.math import isfinite


struct _Validated:
    def __init__(out self):
        pass


struct Margins(Copyable, Equatable, ImplicitlyCopyable):
    """Finite non-negative insets around a figure's plot area.

    Construction establishes the invariants and public reads trust them
    thereafter. Direct mutation of underscore-prefixed storage is out of
    contract; call ``validate`` explicitly when a checkpoint is needed.
    """

    var _left: Float64
    var _right: Float64
    var _top: Float64
    var _bottom: Float64

    def __init__(
        out self, left: Float64, right: Float64, top: Float64, bottom: Float64
    ) raises:
        self._left = left
        self._right = right
        self._top = top
        self._bottom = bottom
        self.validate()

    @staticmethod
    def _from_validated(
        left: Float64, right: Float64, top: Float64, bottom: Float64
    ) -> Self:
        return Self(left, right, top, bottom, _validated=_Validated())

    def __init__(
        out self,
        left: Float64,
        right: Float64,
        top: Float64,
        bottom: Float64,
        *,
        _validated: _Validated,
    ):
        self._left = left
        self._right = right
        self._top = top
        self._bottom = bottom

    def validate(self) raises:
        """Validate the stored insets explicitly."""
        if (
            not isfinite(self._left)
            or not isfinite(self._right)
            or not isfinite(self._top)
            or not isfinite(self._bottom)
        ):
            raise Error(
                "layout margins must be finite; got left=",
                self._left,
                ", right=",
                self._right,
                ", top=",
                self._top,
                ", bottom=",
                self._bottom,
            )
        if (
            self._left < 0.0
            or self._right < 0.0
            or self._top < 0.0
            or self._bottom < 0.0
        ):
            raise Error(
                "layout margins must be non-negative; got left=",
                self._left,
                ", right=",
                self._right,
                ", top=",
                self._top,
                ", bottom=",
                self._bottom,
            )

    def left(self) -> Float64:
        return self._left

    def right(self) -> Float64:
        return self._right

    def top(self) -> Float64:
        return self._top

    def bottom(self) -> Float64:
        return self._bottom

    def __eq__(self, other: Self) -> Bool:
        return (
            self._left == other._left
            and self._right == other._right
            and self._top == other._top
            and self._bottom == other._bottom
        )


struct Rect(Copyable, Equatable, ImplicitlyCopyable):
    """A validated rectangle in logical y-down coordinates.

    ``x`` and ``y`` locate the top-left corner. Width and height are finite and
    non-negative. Construction establishes these invariants and public reads
    trust them thereafter. Direct mutation of underscore-prefixed storage is out
    of contract; call ``validate`` explicitly when a checkpoint is needed.
    """

    var _x: Float64
    var _y: Float64
    var _width: Float64
    var _height: Float64

    def __init__(
        out self, x: Float64, y: Float64, width: Float64, height: Float64
    ) raises:
        self._x = x
        self._y = y
        self._width = width
        self._height = height
        self.validate()

    @staticmethod
    def _from_validated(
        x: Float64, y: Float64, width: Float64, height: Float64
    ) -> Self:
        return Self(x, y, width, height, _validated=_Validated())

    def __init__(
        out self,
        x: Float64,
        y: Float64,
        width: Float64,
        height: Float64,
        *,
        _validated: _Validated,
    ):
        self._x = x
        self._y = y
        self._width = width
        self._height = height

    def validate(self) raises:
        """Validate the stored rectangle explicitly."""
        if (
            not isfinite(self._x)
            or not isfinite(self._y)
            or not isfinite(self._width)
            or not isfinite(self._height)
        ):
            raise Error(
                "layout rectangle values must be finite; got x=",
                self._x,
                ", y=",
                self._y,
                ", width=",
                self._width,
                ", height=",
                self._height,
            )
        if self._width < 0.0 or self._height < 0.0:
            raise Error(
                "layout rectangle width and height must be non-negative; got x=",
                self._x,
                ", y=",
                self._y,
                ", width=",
                self._width,
                ", height=",
                self._height,
            )

    def x(self) -> Float64:
        return self._x

    def y(self) -> Float64:
        return self._y

    def width(self) -> Float64:
        return self._width

    def height(self) -> Float64:
        return self._height

    def __eq__(self, other: Self) -> Bool:
        return (
            self._x == other._x
            and self._y == other._y
            and self._width == other._width
            and self._height == other._height
        )


def plot_area(
    figure_width: Float64, figure_height: Float64, margins: Margins
) raises -> Rect:
    """Return the positive plot area within a logical y-down figure.

    Figure coordinates start at ``(0, 0)`` in the top-left. Increasing x moves
    right and increasing y moves down.
    """
    if not isfinite(figure_width) or not isfinite(figure_height):
        raise Error(
            "figure size must be finite; got width = ",
            figure_width,
            ", height = ",
            figure_height,
        )
    var width = figure_width - margins._left - margins._right
    var height = figure_height - margins._top - margins._bottom
    if width <= 0.0 or height <= 0.0:
        raise Error(
            "plot area must have positive width and height; got plot width = ",
            width,
            ", plot height = ",
            height,
            " (figure ",
            figure_width,
            "x",
            figure_height,
            " minus margins)",
        )
    return Rect._from_validated(margins._left, margins._top, width, height)
