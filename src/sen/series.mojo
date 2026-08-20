"""Renderer-independent line-series semantics."""

from std.collections import List, Optional


def _is_finite(value: Float64) -> Bool:
    return value == value and value - value == 0.0


struct PlotPoint(Copyable, ImplicitlyCopyable):
    """One constructor-validated point in data coordinates.

    Public observations revalidate current storage because Mojo 1.0 struct fields
    remain externally mutable.
    """

    var _x: Float64
    var _y: Float64

    def __init__(out self, x: Float64, y: Float64) raises:
        if not _is_finite(x) or not _is_finite(y):
            raise Error("plot coordinates must be finite")
        self._x = x
        self._y = y

    def _validate(self) raises:
        if not _is_finite(self._x) or not _is_finite(self._y):
            raise Error("plot coordinates must be finite")

    def x(self) raises -> Float64:
        self._validate()
        return self._x

    def y(self) raises -> Float64:
        self._validate()
        return self._y


struct DataBounds(Copyable, ImplicitlyCopyable):
    """A constructor-validated inclusive data-space extent."""

    var _x_min: Float64
    var _x_max: Float64
    var _y_min: Float64
    var _y_max: Float64

    def __init__(
        out self,
        x_min: Float64,
        x_max: Float64,
        y_min: Float64,
        y_max: Float64,
    ) raises:
        if (
            not _is_finite(x_min)
            or not _is_finite(x_max)
            or not _is_finite(y_min)
            or not _is_finite(y_max)
        ):
            raise Error("data bounds must be finite")
        if x_min > x_max:
            raise Error("data bounds x minimum must not exceed x maximum")
        if y_min > y_max:
            raise Error("data bounds y minimum must not exceed y maximum")
        self._x_min = x_min
        self._x_max = x_max
        self._y_min = y_min
        self._y_max = y_max

    def _validate(self) raises:
        if (
            not _is_finite(self._x_min)
            or not _is_finite(self._x_max)
            or not _is_finite(self._y_min)
            or not _is_finite(self._y_max)
        ):
            raise Error("data bounds must be finite")
        if self._x_min > self._x_max:
            raise Error("data bounds x minimum must not exceed x maximum")
        if self._y_min > self._y_max:
            raise Error("data bounds y minimum must not exceed y maximum")

    def x_min(self) raises -> Float64:
        self._validate()
        return self._x_min

    def x_max(self) raises -> Float64:
        self._validate()
        return self._x_max

    def y_min(self) raises -> Float64:
        self._validate()
        return self._y_min

    def y_max(self) raises -> Float64:
        self._validate()
        return self._y_max

    def including(self, point: PlotPoint) raises -> Self:
        self._validate()
        point._validate()
        return Self(
            min(self._x_min, point._x),
            max(self._x_max, point._x),
            min(self._y_min, point._y),
            max(self._y_max, point._y),
        )


struct LineSeries(Copyable):
    """An ordered line-series in data coordinates, independent of rendering."""

    var _points: List[PlotPoint]

    def __init__(out self, var points: List[PlotPoint] = List[PlotPoint]()) raises:
        for index in range(len(points)):
            points[index]._validate()
        self._points = points^

    def _validate(self) raises:
        for index in range(len(self._points)):
            self._points[index]._validate()

    def append(mut self, point: PlotPoint) raises:
        point._validate()
        self._points.append(point)

    def is_empty(self) -> Bool:
        return len(self._points) == 0

    def point_count(self) -> Int:
        return len(self._points)

    def point(self, index: Int) raises -> PlotPoint:
        """Return a point by position, rejecting indices outside the series."""
        if index < 0 or index >= len(self._points):
            raise Error("line-series point index is out of bounds")
        self._points[index]._validate()
        return self._points[index]

    def bounds(self) raises -> Optional[DataBounds]:
        """Return the finite extent, or ``None`` when the series is empty."""
        if self.is_empty():
            return None
        var first = self._points[0]
        first._validate()
        var result = DataBounds(first._x, first._x, first._y, first._y)
        for index in range(1, len(self._points)):
            result = result.including(self._points[index])
        return result


struct Figure(Copyable):
    """A renderer-neutral ordered collection of line series."""

    var _lines: List[LineSeries]

    def __init__(out self):
        self._lines = List[LineSeries]()

    def add_line(mut self, line: LineSeries) raises:
        line._validate()
        self._lines.append(line.copy())

    def is_empty(self) -> Bool:
        return len(self._lines) == 0

    def line_count(self) -> Int:
        return len(self._lines)

    def line(self, index: Int) raises -> LineSeries:
        """Return an owned copy of a line series by position."""
        if index < 0 or index >= len(self._lines):
            raise Error("figure line index is out of bounds")
        self._lines[index]._validate()
        return self._lines[index].copy()
