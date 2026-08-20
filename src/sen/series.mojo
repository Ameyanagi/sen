"""Renderer-independent plotting-series semantics."""

from std.collections import List, Optional
from std.math import isfinite


struct _Validated:
    def __init__(out self):
        pass


struct MissingPolicy(Copyable, Equatable, ImplicitlyCopyable):
    """Govern how NaN coordinates map to topology during one-call ingestion.

    A NaN in either coordinate marks the observation missing. ``ERROR`` rejects
    the first missing observation, ``SEGMENT`` turns missing runs into line gaps,
    and ``DROP`` skips missing observations without creating gaps. NaNs are never
    stored, and non-NaN non-finite coordinates are invalid under every policy.
    """

    var _value: Int

    comptime ERROR = MissingPolicy(_value=0)
    comptime SEGMENT = MissingPolicy(_value=1)
    comptime DROP = MissingPolicy(_value=2)

    def __init__(out self, *, _value: Int):
        self._value = _value

    def __eq__(self, other: Self) -> Bool:
        return self._value == other._value


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

    @staticmethod
    def _from_xy_missing(
        x: Span[Float64, ...],
        y: Span[Float64, ...],
        missing: MissingPolicy,
    ) raises -> Self:
        if len(x) != len(y):
            raise Error("x and y coordinate sequences must have equal length")
        var xs = List[Float64](capacity=len(x))
        var ys = List[Float64](capacity=len(y))
        var segment_starts = List[Int]()
        var gap_before_next = False
        for index in range(len(x)):
            var x_coordinate = x[index]
            var y_coordinate = y[index]
            var x_is_nan = x_coordinate != x_coordinate
            var y_is_nan = y_coordinate != y_coordinate
            if (not x_is_nan and not isfinite(x_coordinate)) or (
                not y_is_nan and not isfinite(y_coordinate)
            ):
                raise Error("plot coordinates must be finite")
            var is_missing = x_is_nan or y_is_nan
            if is_missing:
                if missing == MissingPolicy.ERROR:
                    raise Error(
                        "missing value at index ",
                        index,
                        " (x=",
                        x_coordinate,
                        ", y=",
                        y_coordinate,
                        (
                            "); pass missing=MissingPolicy.SEGMENT or "
                            "MissingPolicy.DROP to handle gaps"
                        ),
                    )
                if missing == MissingPolicy.SEGMENT and len(xs) > 0:
                    gap_before_next = True
                continue
            if len(xs) == 0:
                segment_starts.append(0)
            elif gap_before_next:
                segment_starts.append(len(xs))
            xs.append(x_coordinate)
            ys.append(y_coordinate)
            gap_before_next = False
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


struct ScatterSeries(Copyable):
    """An ordered marker-only series with finite structure-of-arrays storage.

    Construction and mutation establish equal-length finite coordinate buffers,
    and public reads trust them thereafter. Direct mutation of underscore-prefixed
    storage is out of contract; call ``validate`` explicitly when a checkpoint is
    needed.
    """

    var _xs: List[Float64]
    var _ys: List[Float64]

    def __init__(out self):
        """Construct an empty scatter series."""
        self._xs = List[Float64]()
        self._ys = List[Float64]()

    def __init__(
        out self,
        var xs: List[Float64],
        var ys: List[Float64],
        *,
        _validated: _Validated,
    ):
        self._xs = xs^
        self._ys = ys^

    @staticmethod
    def from_xy(x: Span[Float64, ...], y: Span[Float64, ...]) raises -> Self:
        """Build a marker series from equal-length finite coordinate spans."""
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
        return Self(xs^, ys^, _validated=_Validated())

    @staticmethod
    def _from_xy_missing(
        x: Span[Float64, ...],
        y: Span[Float64, ...],
        missing: MissingPolicy,
    ) raises -> Self:
        if len(x) != len(y):
            raise Error("x and y coordinate sequences must have equal length")
        var xs = List[Float64](capacity=len(x))
        var ys = List[Float64](capacity=len(y))
        for index in range(len(x)):
            var x_coordinate = x[index]
            var y_coordinate = y[index]
            var x_is_nan = x_coordinate != x_coordinate
            var y_is_nan = y_coordinate != y_coordinate
            if (not x_is_nan and not isfinite(x_coordinate)) or (
                not y_is_nan and not isfinite(y_coordinate)
            ):
                raise Error("plot coordinates must be finite")
            var is_missing = x_is_nan or y_is_nan
            if is_missing:
                if missing == MissingPolicy.ERROR:
                    raise Error(
                        "missing value at index ",
                        index,
                        " (x=",
                        x_coordinate,
                        ", y=",
                        y_coordinate,
                        (
                            "); pass missing=MissingPolicy.SEGMENT or "
                            "MissingPolicy.DROP to handle gaps"
                        ),
                    )
                continue
            xs.append(x_coordinate)
            ys.append(y_coordinate)
        return Self(xs^, ys^, _validated=_Validated())

    def append(mut self, point: PlotPoint) raises:
        """Append one validated point."""
        point.validate()
        self._xs.append(point._x)
        self._ys.append(point._y)

    def validate(self) raises:
        """Validate coordinate buffers explicitly."""
        if len(self._xs) != len(self._ys):
            raise Error("scatter-series coordinate buffers must have equal length")
        for index in range(len(self._xs)):
            if not isfinite(self._xs[index]) or not isfinite(self._ys[index]):
                raise Error("plot coordinates must be finite")

    def point_count(self) -> Int:
        return len(self._xs)

    def is_empty(self) -> Bool:
        return len(self._xs) == 0

    def point(self, index: Int) raises -> PlotPoint:
        """Return a point by position, rejecting indices outside the series."""
        if index < 0 or index >= len(self._xs):
            raise Error("scatter-series point index is out of bounds")
        return PlotPoint._from_validated(self._xs[index], self._ys[index])

    def bounds(self) raises -> DataBounds:
        """Return the trusted extent, rejecting an empty series."""
        if self.is_empty():
            raise Error("empty scatter-series has no data bounds")
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


struct _SeriesKind(Copyable, ImplicitlyCopyable):
    var _value: Int

    comptime LINE = _SeriesKind(_value=0)
    comptime SCATTER = _SeriesKind(_value=1)

    def __init__(out self, *, _value: Int):
        self._value = _value


struct _SeriesOrder(Copyable, ImplicitlyCopyable):
    var kind: _SeriesKind
    var index: Int

    def __init__(out self, kind: _SeriesKind, index: Int):
        self.kind = kind
        self.index = index


struct Figure(Copyable):
    """A renderer-neutral collection preserving interleaved series draw order.

    Lower-level ``add_line`` and ``add_scatter`` calls take ownership without
    copying and store empty labels. One-call ``line`` and ``scatter`` ingestion
    validates and builds new series before insertion. Constructed series are
    trusted on insertion and public operations trust them thereafter. Direct
    mutation of underscore-prefixed storage is out of contract; call ``validate``
    explicitly when a checkpoint is needed.
    """

    var _lines: List[LineSeries]
    var _line_labels: List[String]
    var _scatters: List[ScatterSeries]
    var _scatter_labels: List[String]
    var _order: List[_SeriesOrder]
    var _title: String
    var _x_label: String
    var _y_label: String

    def __init__(out self):
        self._lines = List[LineSeries]()
        self._line_labels = List[String]()
        self._scatters = List[ScatterSeries]()
        self._scatter_labels = List[String]()
        self._order = List[_SeriesOrder]()
        self._title = String()
        self._x_label = String()
        self._y_label = String()

    def _insert_line(mut self, var line: LineSeries, var label: String):
        var index = len(self._lines)
        self._lines.append(line^)
        self._line_labels.append(label^)
        self._order.append(_SeriesOrder(_SeriesKind.LINE, index))

    def _insert_scatter(mut self, var scatter: ScatterSeries, var label: String):
        var index = len(self._scatters)
        self._scatters.append(scatter^)
        self._scatter_labels.append(label^)
        self._order.append(_SeriesOrder(_SeriesKind.SCATTER, index))

    def add_line(mut self, var line: LineSeries):
        """Take ownership of a prebuilt line series with an empty label."""
        self._insert_line(line^, String())

    def add_scatter(mut self, var scatter: ScatterSeries):
        """Take ownership of a prebuilt scatter series with an empty label."""
        self._insert_scatter(scatter^, String())

    def line(
        mut self,
        x: Span[Float64, ...],
        y: Span[Float64, ...],
        *,
        var label: String = String(),
        missing: MissingPolicy = MissingPolicy.ERROR,
    ) raises:
        """Build and insert a line series using the requested missing-data policy."""
        var series = LineSeries._from_xy_missing(x, y, missing)
        self._insert_line(series^, label^)

    def scatter(
        mut self,
        x: Span[Float64, ...],
        y: Span[Float64, ...],
        *,
        var label: String = String(),
        missing: MissingPolicy = MissingPolicy.ERROR,
    ) raises:
        """Build and insert markers using the requested missing-data policy.

        Because disconnected topology has no meaning for markers, ``SEGMENT``
        behaves identically to ``DROP``. ``ERROR`` still rejects the first NaN.
        """
        var series = ScatterSeries._from_xy_missing(x, y, missing)
        self._insert_scatter(series^, label^)

    def set_title(mut self, var title: String):
        """Set arbitrary title text; no input validation is required."""
        self._title = title^

    def set_x_label(mut self, var label: String):
        """Set arbitrary x-axis label text; no input validation is required."""
        self._x_label = label^

    def set_y_label(mut self, var label: String):
        """Set arbitrary y-axis label text; no input validation is required."""
        self._y_label = label^

    def title(self) -> ref[self._title] String:
        return self._title

    def x_label(self) -> ref[self._x_label] String:
        return self._x_label

    def y_label(self) -> ref[self._y_label] String:
        return self._y_label

    def validate(self) raises:
        """Validate stored series and insertion-order metadata explicitly."""
        for index in range(len(self._lines)):
            self._lines[index].validate()
        for index in range(len(self._scatters)):
            self._scatters[index].validate()
        if len(self._line_labels) != len(self._lines):
            raise Error("figure line labels must match stored line series")
        if len(self._scatter_labels) != len(self._scatters):
            raise Error("figure scatter labels must match stored scatter series")
        if len(self._order) != len(self._lines) + len(self._scatters):
            raise Error("figure series order must include every stored series")

        var seen_lines = List[Bool](capacity=len(self._lines))
        for _ in range(len(self._lines)):
            seen_lines.append(False)
        var seen_scatters = List[Bool](capacity=len(self._scatters))
        for _ in range(len(self._scatters)):
            seen_scatters.append(False)
        for order_index in range(len(self._order)):
            ref entry = self._order[order_index]
            if entry.kind._value == _SeriesKind.LINE._value:
                if entry.index < 0 or entry.index >= len(self._lines):
                    raise Error("figure line order index is out of bounds")
                if seen_lines[entry.index]:
                    raise Error("figure series order must not contain duplicates")
                seen_lines[entry.index] = True
            elif entry.kind._value == _SeriesKind.SCATTER._value:
                if entry.index < 0 or entry.index >= len(self._scatters):
                    raise Error("figure scatter order index is out of bounds")
                if seen_scatters[entry.index]:
                    raise Error("figure series order must not contain duplicates")
                seen_scatters[entry.index] = True
            else:
                raise Error("figure series order contains an unknown kind")

    def is_empty(self) -> Bool:
        return len(self._lines) == 0 and len(self._scatters) == 0

    def line_count(self) -> Int:
        return len(self._lines)

    def scatter_count(self) -> Int:
        return len(self._scatters)

    def bounds(self) raises -> DataBounds:
        """Return combined bounds for every nonempty line and scatter series.

        Empty series do not contribute an extent. A figure with no stored points
        has no data domain and is rejected.
        """
        var combined: Optional[DataBounds] = None
        for index in range(len(self._lines)):
            if self._lines[index].is_empty():
                continue
            var current = self._lines[index].bounds()
            if combined:
                var existing = combined.value()
                combined = DataBounds._from_validated(
                    min(existing._x_min, current._x_min),
                    max(existing._x_max, current._x_max),
                    min(existing._y_min, current._y_min),
                    max(existing._y_max, current._y_max),
                )
            else:
                combined = current
        for index in range(len(self._scatters)):
            if self._scatters[index].is_empty():
                continue
            var current = self._scatters[index].bounds()
            if combined:
                var existing = combined.value()
                combined = DataBounds._from_validated(
                    min(existing._x_min, current._x_min),
                    max(existing._x_max, current._x_max),
                    min(existing._y_min, current._y_min),
                    max(existing._y_max, current._y_max),
                )
            else:
                combined = current
        if not combined:
            raise Error("empty figure has no data bounds")
        return combined.value()

    def line(self, index: Int) raises -> ref[self._lines[index]] LineSeries:
        """Return a read reference to a line series by position."""
        if index < 0 or index >= len(self._lines):
            raise Error("figure line index is out of bounds")
        return self._lines[index]

    def scatter(self, index: Int) raises -> ref[self._scatters[index]] ScatterSeries:
        """Return a read reference to a scatter series by position."""
        if index < 0 or index >= len(self._scatters):
            raise Error("figure scatter index is out of bounds")
        return self._scatters[index]

    def line_label(self, index: Int) raises -> ref[self._line_labels[index]] String:
        """Return the label for a line-series position."""
        if index < 0 or index >= len(self._line_labels):
            raise Error("figure line-label index is out of bounds")
        return self._line_labels[index]

    def scatter_label(
        self, index: Int
    ) raises -> ref[self._scatter_labels[index]] String:
        """Return the label for a scatter-series position."""
        if index < 0 or index >= len(self._scatter_labels):
            raise Error("figure scatter-label index is out of bounds")
        return self._scatter_labels[index]

    def _series_count(self) -> Int:
        return len(self._order)

    def _series_is_line(self, index: Int) -> Bool:
        return self._order[index].kind._value == _SeriesKind.LINE._value

    def _series_index(self, index: Int) -> Int:
        return self._order[index].index

    def save_svg(self, path: StringSlice) raises:
        """Render at 640 by 480 with default margins and save to ``path``."""
        from .svg import render_svg, save_svg

        var svg = render_svg(self)
        save_svg(path, svg)
