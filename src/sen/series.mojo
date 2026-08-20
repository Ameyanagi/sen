"""Renderer-independent line-series semantics."""

from std.collections import List
from std.math import isfinite


struct _Validated:
    def __init__(out self):
        pass


struct PlotPoint(Copyable, ImplicitlyCopyable):
    """One constructor-validated point in data coordinates.

    Construction establishes the coordinate invariants and public operations trust
    them thereafter. Direct mutation of underscore-prefixed storage is out of
    contract; call ``validate`` explicitly when a checkpoint is needed.
    """

    var _x: Float64
    var _y: Float64

    def __init__(out self, x: Float64, y: Float64) raises:
        if not isfinite(x) or not isfinite(y):
            raise Error("plot coordinates must be finite")
        self._x = x
        self._y = y

    @staticmethod
    def _from_validated(x: Float64, y: Float64) -> Self:
        return Self(x, y, _validated=_Validated())

    def __init__(out self, x: Float64, y: Float64, *, _validated: _Validated):
        self._x = x
        self._y = y

    def validate(self) raises:
        """Validate the stored coordinates explicitly."""
        if not isfinite(self._x) or not isfinite(self._y):
            raise Error("plot coordinates must be finite")

    def x(self) -> Float64:
        return self._x

    def y(self) -> Float64:
        return self._y


struct DataBounds(Copyable, ImplicitlyCopyable):
    """A constructor-validated inclusive data-space extent.

    Construction establishes finite ordered extents and public operations trust
    them thereafter. Direct mutation of underscore-prefixed storage is out of
    contract; call ``validate`` explicitly when a checkpoint is needed.
    """

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
            not isfinite(x_min)
            or not isfinite(x_max)
            or not isfinite(y_min)
            or not isfinite(y_max)
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

    @staticmethod
    def _from_validated(
        x_min: Float64, x_max: Float64, y_min: Float64, y_max: Float64
    ) -> Self:
        return Self(
            x_min,
            x_max,
            y_min,
            y_max,
            _validated=_Validated(),
        )

    def __init__(
        out self,
        x_min: Float64,
        x_max: Float64,
        y_min: Float64,
        y_max: Float64,
        *,
        _validated: _Validated,
    ):
        self._x_min = x_min
        self._x_max = x_max
        self._y_min = y_min
        self._y_max = y_max

    def validate(self) raises:
        """Validate the stored extents explicitly."""
        if (
            not isfinite(self._x_min)
            or not isfinite(self._x_max)
            or not isfinite(self._y_min)
            or not isfinite(self._y_max)
        ):
            raise Error("data bounds must be finite")
        if self._x_min > self._x_max:
            raise Error("data bounds x minimum must not exceed x maximum")
        if self._y_min > self._y_max:
            raise Error("data bounds y minimum must not exceed y maximum")

    def x_min(self) -> Float64:
        return self._x_min

    def x_max(self) -> Float64:
        return self._x_max

    def y_min(self) -> Float64:
        return self._y_min

    def y_max(self) -> Float64:
        return self._y_max

    def including(self, point: PlotPoint) -> Self:
        """Return the trusted extent expanded to include ``point``."""
        return Self._from_validated(
            min(self._x_min, point._x),
            max(self._x_max, point._x),
            min(self._y_min, point._y),
            max(self._y_max, point._y),
        )


struct LineSeries(Copyable):
    """An ordered, explicitly segmented line-series in data coordinates.

    Every stored point is finite. Missing observations are represented by
    starting a new segment at the next finite point, never by storing NaN.
    Construction and mutation establish these invariants and public operations
    trust them thereafter. Direct mutation of underscore-prefixed storage is out
    of contract; call ``validate`` explicitly when a checkpoint is needed.
    """

    var _xs: List[Float64]
    var _ys: List[Float64]
    var _segment_starts: List[Int]

    def __init__(out self, var points: List[PlotPoint] = List[PlotPoint]()) raises:
        self._xs = List[Float64](capacity=len(points))
        self._ys = List[Float64](capacity=len(points))
        for index in range(len(points)):
            self._xs.append(points[index]._x)
            self._ys.append(points[index]._y)
        self._segment_starts = List[Int]()
        if len(self._xs) > 0:
            self._segment_starts.append(0)
        self.validate()

    def __init__(
        out self, var points: List[PlotPoint], var segment_starts: List[Int]
    ) raises:
        self._xs = List[Float64](capacity=len(points))
        self._ys = List[Float64](capacity=len(points))
        for index in range(len(points)):
            self._xs.append(points[index]._x)
            self._ys.append(points[index]._y)
        self._segment_starts = segment_starts^
        self.validate()

    def __init__(
        out self,
        var xs: List[Float64],
        var ys: List[Float64],
        var segment_starts: List[Int],
        *,
        _validated: _Validated,
    ):
        self._xs = xs^
        self._ys = ys^
        self._segment_starts = segment_starts^

    @staticmethod
    def from_xy(x: Span[Float64, ...], y: Span[Float64, ...]) raises -> Self:
        """Build a series from coordinate spans using the bulk-data fast path.

        ``List[Float64]`` values convert implicitly to the accepted span shape.
        """
        if len(x) != len(y):
            raise Error("x and y coordinate sequences must have equal length")
        var xs = List[Float64](capacity=len(x))
        var ys = List[Float64](capacity=len(y))
        for index in range(len(x)):
            var x_coordinate = x[index]
            var y_coordinate = y[index]
            if not isfinite(x_coordinate) or not isfinite(y_coordinate):
                raise Error("plot coordinates must be finite")
            xs.append(x_coordinate)
            ys.append(y_coordinate)
        var segment_starts = List[Int]()
        if len(xs) > 0:
            segment_starts.append(0)
        return Self(
            xs^,
            ys^,
            segment_starts^,
            _validated=_Validated(),
        )

    def validate(self) raises:
        """Validate coordinate buffers and segment topology explicitly."""
        if len(self._xs) != len(self._ys):
            raise Error("line-series coordinate buffers must have equal length")
        for index in range(len(self._xs)):
            if not isfinite(self._xs[index]) or not isfinite(self._ys[index]):
                raise Error("plot coordinates must be finite")
        if len(self._xs) == 0:
            if len(self._segment_starts) != 0:
                raise Error("empty line-series must not contain segments")
            return
        if len(self._segment_starts) == 0 or self._segment_starts[0] != 0:
            raise Error("nonempty line-series must start with segment zero")
        var previous = -1
        for index in range(len(self._segment_starts)):
            var start = self._segment_starts[index]
            if start <= previous:
                raise Error("line-series segment starts must be strictly increasing")
            if start >= len(self._xs):
                raise Error("line-series segment start is outside point storage")
            previous = start

    def append(mut self, point: PlotPoint) raises:
        point.validate()
        if len(self._xs) == 0:
            self._segment_starts.append(0)
        self._xs.append(point._x)
        self._ys.append(point._y)

    def append_all(mut self, x: Span[Float64, ...], y: Span[Float64, ...]) raises:
        """Append a validated coordinate batch to the current segment."""
        if len(x) != len(y):
            raise Error("x and y coordinate sequences must have equal length")
        for index in range(len(x)):
            if not isfinite(x[index]) or not isfinite(y[index]):
                raise Error("plot coordinates must be finite")
        if len(x) == 0:
            return
        if len(self._xs) == 0:
            self._segment_starts.append(0)
        for index in range(len(x)):
            self._xs.append(x[index])
            self._ys.append(y[index])

    def start_segment(mut self, point: PlotPoint) raises:
        """Append ``point`` as the first point after an explicit data gap."""
        point.validate()
        if len(self._xs) == 0:
            raise Error("a new line segment requires an existing point")
        var start = len(self._xs)
        self._xs.append(point._x)
        self._ys.append(point._y)
        self._segment_starts.append(start)

    def is_empty(self) -> Bool:
        return len(self._xs) == 0

    def point_count(self) -> Int:
        return len(self._xs)

    def segment_count(self) -> Int:
        """Return the connected-segment count."""
        return len(self._segment_starts)

    def point(self, index: Int) raises -> PlotPoint:
        """Return a point by position, rejecting indices outside the series."""
        if index < 0 or index >= len(self._xs):
            raise Error("line-series point index is out of bounds")
        return PlotPoint._from_validated(self._xs[index], self._ys[index])

    def segment_point_count(self, segment_index: Int) raises -> Int:
        """Return the number of points in one connected line segment."""
        if segment_index < 0 or segment_index >= len(self._segment_starts):
            raise Error("line-series segment index is out of bounds")
        var end = len(self._xs)
        if segment_index + 1 < len(self._segment_starts):
            end = self._segment_starts[segment_index + 1]
        return end - self._segment_starts[segment_index]

    def segment_point(self, segment_index: Int, point_index: Int) raises -> PlotPoint:
        """Return a point by segment-local position."""
        var count = self.segment_point_count(segment_index)
        if point_index < 0 or point_index >= count:
            raise Error("line-segment point index is out of bounds")
        var index = self._segment_starts[segment_index] + point_index
        return PlotPoint._from_validated(self._xs[index], self._ys[index])

    def bounds(self) raises -> DataBounds:
        """Return the trusted extent, rejecting an empty series."""
        if self.is_empty():
            raise Error("empty line-series has no data bounds")
        var x_min = self._xs[0]
        var x_max = self._xs[0]
        var y_min = self._ys[0]
        var y_max = self._ys[0]
        for index in range(1, len(self._xs)):
            x_min = min(x_min, self._xs[index])
            x_max = max(x_max, self._xs[index])
            y_min = min(y_min, self._ys[index])
            y_max = max(y_max, self._ys[index])
        return DataBounds._from_validated(x_min, x_max, y_min, y_max)


struct Figure(Copyable):
    """A renderer-neutral ordered collection of line series.

    Inserted series are validated and public operations trust them thereafter.
    Direct mutation of underscore-prefixed storage is out of contract; call
    ``validate`` explicitly when a checkpoint is needed.
    """

    var _lines: List[LineSeries]

    def __init__(out self):
        self._lines = List[LineSeries]()

    def add_line(mut self, line: LineSeries) raises:
        line.validate()
        self._lines.append(line.copy())

    def validate(self) raises:
        """Validate every stored line series explicitly."""
        for index in range(len(self._lines)):
            self._lines[index].validate()

    def is_empty(self) -> Bool:
        return len(self._lines) == 0

    def line_count(self) -> Int:
        return len(self._lines)

    def line(self, index: Int) raises -> LineSeries:
        """Return an owned copy of a line series by position."""
        if index < 0 or index >= len(self._lines):
            raise Error("figure line index is out of bounds")
        return self._lines[index].copy()
