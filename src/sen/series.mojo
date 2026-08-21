"""Renderer-independent plotting-series semantics."""

from std.collections import List, Optional
from std.math import isfinite

from .style import SeriesStyle


struct _Validated:
    def __init__(out self):
        pass


struct MissingPolicy(Copyable, Equatable, ImplicitlyCopyable):
    """Govern how NaN coordinates map to topology during one-call ingestion.

    A NaN in either coordinate marks the observation missing. ``ERROR`` rejects
    the first missing observation, ``SEGMENT`` turns missing runs into line gaps,
    and ``DROP`` skips missing observations without creating gaps. NaNs are never
    stored, and non-NaN non-finite coordinates are invalid under every policy.
    The nominal constants and equality are non-raising; ingestion always scans
    from index zero and therefore reports or transforms missing data
    deterministically.
    """

    var _value: Int

    comptime ERROR = MissingPolicy(_value=0)
    comptime SEGMENT = MissingPolicy(_value=1)
    comptime DROP = MissingPolicy(_value=2)

    def __init__(out self, *, _value: Int):
        """Construct a policy discriminant for library-defined constants."""
        self._value = _value

    def __eq__(self, other: Self) -> Bool:
        """Return deterministic discriminant equality without raising."""
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
            raise Error("plot coordinates must be finite; got x=", x, ", y=", y)
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
            raise Error(
                "plot coordinates must be finite; got x=",
                self._x,
                ", y=",
                self._y,
            )

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
            raise Error(
                "data bounds must be finite; got x_min=",
                x_min,
                " x_max=",
                x_max,
                " y_min=",
                y_min,
                " y_max=",
                y_max,
            )
        if x_min > x_max:
            raise Error(
                "data bounds x minimum must not exceed x maximum; got x_min = ",
                x_min,
                ", x_max = ",
                x_max,
            )
        if y_min > y_max:
            raise Error(
                "data bounds y minimum must not exceed y maximum; got y_min = ",
                y_min,
                ", y_max = ",
                y_max,
            )
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
            raise Error(
                "data bounds must be finite; got x_min=",
                self._x_min,
                " x_max=",
                self._x_max,
                " y_min=",
                self._y_min,
                " y_max=",
                self._y_max,
            )
        if self._x_min > self._x_max:
            raise Error(
                "data bounds x minimum must not exceed x maximum; got x_min = ",
                self._x_min,
                ", x_max = ",
                self._x_max,
            )
        if self._y_min > self._y_max:
            raise Error(
                "data bounds y minimum must not exceed y maximum; got y_min = ",
                self._y_min,
                ", y_max = ",
                self._y_max,
            )

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
    def from_xy(
        x: Span[Float64, ImmutAnyOrigin],
        y: Span[Float64, ImmutAnyOrigin],
    ) raises -> Self:
        """Build a series from coordinate spans using the bulk-data fast path.

        ``List[Float64]`` values convert implicitly to the accepted span shape.
        """
        if len(x) != len(y):
            raise Error(
                "x and y coordinate sequences must have equal length; got len(x) = ",
                len(x),
                ", len(y) = ",
                len(y),
            )
        var xs = List[Float64](capacity=len(x))
        var ys = List[Float64](capacity=len(y))
        for index in range(len(x)):
            var x_coordinate = x[index]
            var y_coordinate = y[index]
            if not isfinite(x_coordinate) or not isfinite(y_coordinate):
                raise Error(
                    "coordinate at index ",
                    index,
                    " (x=",
                    x_coordinate,
                    ", y=",
                    y_coordinate,
                    ") must be finite",
                )
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
        x: Span[Float64, ImmutAnyOrigin],
        y: Span[Float64, ImmutAnyOrigin],
        missing: MissingPolicy,
    ) raises -> Self:
        if len(x) != len(y):
            raise Error(
                "x and y coordinate sequences must have equal length; got len(x) = ",
                len(x),
                ", len(y) = ",
                len(y),
            )
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
                raise Error(
                    "coordinate at index ",
                    index,
                    " (x=",
                    x_coordinate,
                    ", y=",
                    y_coordinate,
                    ") must be finite",
                )
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
            raise Error(
                "line-series coordinate buffers must have equal length; got ",
                len(self._xs),
                " x values and ",
                len(self._ys),
                " y values",
            )
        for index in range(len(self._xs)):
            if not isfinite(self._xs[index]) or not isfinite(self._ys[index]):
                raise Error(
                    "coordinate at index ",
                    index,
                    " (x=",
                    self._xs[index],
                    ", y=",
                    self._ys[index],
                    ") must be finite",
                )
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
                raise Error(
                    "line-series segment starts must be strictly increasing; got ",
                    start,
                    " after ",
                    previous,
                )
            if start >= len(self._xs):
                raise Error(
                    "line-series segment start must be within [0, ",
                    len(self._xs),
                    "); got ",
                    start,
                )
            previous = start

    def append(mut self, point: PlotPoint) raises:
        point.validate()
        if len(self._xs) == 0:
            self._segment_starts.append(0)
        self._xs.append(point._x)
        self._ys.append(point._y)

    def append_all(
        mut self,
        x: Span[Float64, ImmutAnyOrigin],
        y: Span[Float64, ImmutAnyOrigin],
    ) raises:
        """Append a validated coordinate batch to the current segment."""
        if len(x) != len(y):
            raise Error(
                "x and y coordinate sequences must have equal length; got len(x) = ",
                len(x),
                ", len(y) = ",
                len(y),
            )
        for index in range(len(x)):
            if not isfinite(x[index]) or not isfinite(y[index]):
                raise Error(
                    "coordinate at index ",
                    index,
                    " (x=",
                    x[index],
                    ", y=",
                    y[index],
                    ") must be finite",
                )
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
            raise Error(
                "a new line segment requires an existing point; append the first "
                "point with append() before start_segment()"
            )
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
            raise Error(
                "line-series point index must be within [0, ",
                len(self._xs),
                "); got ",
                index,
            )
        return PlotPoint._from_validated(self._xs[index], self._ys[index])

    def segment_point_count(self, segment_index: Int) raises -> Int:
        """Return the number of points in one connected line segment."""
        if segment_index < 0 or segment_index >= len(self._segment_starts):
            raise Error(
                "line-series segment index must be within [0, ",
                len(self._segment_starts),
                "); got ",
                segment_index,
            )
        var end = len(self._xs)
        if segment_index + 1 < len(self._segment_starts):
            end = self._segment_starts[segment_index + 1]
        return end - self._segment_starts[segment_index]

    def segment_point(self, segment_index: Int, point_index: Int) raises -> PlotPoint:
        """Return a point by segment-local position."""
        var count = self.segment_point_count(segment_index)
        if point_index < 0 or point_index >= count:
            raise Error(
                "line-segment point index must be within [0, ",
                count,
                "); got ",
                point_index,
            )
        var index = self._segment_starts[segment_index] + point_index
        return PlotPoint._from_validated(self._xs[index], self._ys[index])

    def bounds(self) raises -> DataBounds:
        """Return the trusted extent, rejecting an empty series."""
        if self.is_empty():
            raise Error(
                "empty line-series has no data bounds; append points before "
                "requesting bounds"
            )
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
    needed. Bulk construction and mutation reject unequal lengths or non-finite
    coordinates before storing them. Point order and bounds traversal are
    deterministic.
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
    def from_xy(
        x: Span[Float64, ImmutAnyOrigin],
        y: Span[Float64, ImmutAnyOrigin],
    ) raises -> Self:
        """Build markers in input order; reject unequal lengths or non-finite data."""
        if len(x) != len(y):
            raise Error(
                "x and y coordinate sequences must have equal length; got len(x) = ",
                len(x),
                ", len(y) = ",
                len(y),
            )
        var xs = List[Float64](capacity=len(x))
        var ys = List[Float64](capacity=len(y))
        for index in range(len(x)):
            var x_coordinate = x[index]
            var y_coordinate = y[index]
            if not isfinite(x_coordinate) or not isfinite(y_coordinate):
                raise Error(
                    "coordinate at index ",
                    index,
                    " (x=",
                    x_coordinate,
                    ", y=",
                    y_coordinate,
                    ") must be finite",
                )
            xs.append(x_coordinate)
            ys.append(y_coordinate)
        return Self(xs^, ys^, _validated=_Validated())

    @staticmethod
    def _from_xy_missing(
        x: Span[Float64, ImmutAnyOrigin],
        y: Span[Float64, ImmutAnyOrigin],
        missing: MissingPolicy,
    ) raises -> Self:
        if len(x) != len(y):
            raise Error(
                "x and y coordinate sequences must have equal length; got len(x) = ",
                len(x),
                ", len(y) = ",
                len(y),
            )
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
                raise Error(
                    "coordinate at index ",
                    index,
                    " (x=",
                    x_coordinate,
                    ", y=",
                    y_coordinate,
                    ") must be finite",
                )
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
        """Append deterministically after explicit point validation may raise."""
        point.validate()
        self._xs.append(point._x)
        self._ys.append(point._y)

    def validate(self) raises:
        """Validate equal lengths then finite coordinates in stable index order."""
        if len(self._xs) != len(self._ys):
            raise Error(
                "scatter-series coordinate buffers must have equal length; got ",
                len(self._xs),
                " x values and ",
                len(self._ys),
                " y values",
            )
        for index in range(len(self._xs)):
            if not isfinite(self._xs[index]) or not isfinite(self._ys[index]):
                raise Error(
                    "coordinate at index ",
                    index,
                    " (x=",
                    self._xs[index],
                    ", y=",
                    self._ys[index],
                    ") must be finite",
                )

    def point_count(self) -> Int:
        """Return the deterministic marker count without raising."""
        return len(self._xs)

    def is_empty(self) -> Bool:
        """Return whether no markers are stored; this never raises."""
        return len(self._xs) == 0

    def point(self, index: Int) raises -> PlotPoint:
        """Return the exact point by position; reject an out-of-range index."""
        if index < 0 or index >= len(self._xs):
            raise Error(
                "scatter-series point index must be within [0, ",
                len(self._xs),
                "); got ",
                index,
            )
        return PlotPoint._from_validated(self._xs[index], self._ys[index])

    def bounds(self) raises -> DataBounds:
        """Return deterministic index-order bounds, rejecting an empty series."""
        if self.is_empty():
            raise Error(
                "empty scatter-series has no data bounds; append points before "
                "requesting bounds"
            )
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


struct AxisKind(Copyable, Equatable, ImplicitlyCopyable):
    """Select deterministic linear or base-10 logarithmic axis semantics.

    Setters accepting this nominal value are non-raising. A logarithmic axis
    validates positive data and explicit limits only when rendering, where the
    effective domain and insertion-order series context are available.
    """

    var _value: Int

    comptime LINEAR = AxisKind(_value=0)
    comptime LOG10 = AxisKind(_value=1)

    def __init__(out self, *, _value: Int):
        """Construct an axis discriminant for library-defined constants."""
        self._value = _value

    def __eq__(self, other: Self) -> Bool:
        """Return whether both values select the same axis transform."""
        return self._value == other._value


struct LegendPosition(Copyable, Equatable, ImplicitlyCopyable):
    """A deterministic nominal legend position; ``NONE`` suppresses rendering.

    Constants, construction, and equality are non-raising. A visible legend is
    still emitted only when at least one series label is nonempty.
    """

    var _value: Int

    comptime UPPER_RIGHT = LegendPosition(_value=0)
    comptime UPPER_LEFT = LegendPosition(_value=1)
    comptime LOWER_LEFT = LegendPosition(_value=2)
    comptime LOWER_RIGHT = LegendPosition(_value=3)
    comptime NONE = LegendPosition(_value=4)

    def __init__(out self, *, _value: Int):
        """Construct a position discriminant for library-defined constants."""
        self._value = _value

    def __eq__(self, other: Self) -> Bool:
        """Return deterministic discriminant equality without raising."""
        return self._value == other._value


struct Figure(Copyable):
    """A renderer-neutral collection preserving interleaved series draw order.

    Lower-level ``add_line`` and ``add_scatter`` calls take ownership without
    copying and store empty labels. One-call ``line`` and ``scatter`` ingestion
    validates and builds new series before insertion. Constructed series are
    trusted on insertion and public operations trust them thereafter. Direct
    mutation of underscore-prefixed storage is out of contract; call ``validate``
    explicitly when a checkpoint is needed. All stored ordering, palette,
    legend, axis, and grid state is consumed deterministically by renderers;
    fallible ingestion, limits, lookup, bounds, validation, rendering, and I/O
    methods document their rejection conditions.
    """

    var _lines: List[LineSeries]
    var _line_labels: List[String]
    var _line_styles: List[SeriesStyle]
    var _scatters: List[ScatterSeries]
    var _scatter_labels: List[String]
    var _scatter_styles: List[SeriesStyle]
    var _order: List[_SeriesOrder]
    var _title: String
    var _x_label: String
    var _y_label: String
    var _legend_position: LegendPosition
    var _grid_enabled: Bool
    var _x_scale: AxisKind
    var _y_scale: AxisKind
    var _has_x_limits: Bool
    var _x_limit_lo: Float64
    var _x_limit_hi: Float64
    var _has_y_limits: Bool
    var _y_limit_lo: Float64
    var _y_limit_hi: Float64

    def __init__(out self):
        """Construct deterministic empty linear-axis defaults without raising."""
        self._lines = List[LineSeries]()
        self._line_labels = List[String]()
        self._line_styles = List[SeriesStyle]()
        self._scatters = List[ScatterSeries]()
        self._scatter_labels = List[String]()
        self._scatter_styles = List[SeriesStyle]()
        self._order = List[_SeriesOrder]()
        self._title = String()
        self._x_label = String()
        self._y_label = String()
        self._legend_position = LegendPosition.UPPER_RIGHT
        self._grid_enabled = False
        self._x_scale = AxisKind.LINEAR
        self._y_scale = AxisKind.LINEAR
        self._has_x_limits = False
        self._x_limit_lo = 0.0
        self._x_limit_hi = 1.0
        self._has_y_limits = False
        self._y_limit_lo = 0.0
        self._y_limit_hi = 1.0

    def _insert_line(
        mut self, var line: LineSeries, var label: String, style: SeriesStyle
    ):
        var index = len(self._lines)
        self._lines.append(line^)
        self._line_labels.append(label^)
        self._line_styles.append(style)
        self._order.append(_SeriesOrder(_SeriesKind.LINE, index))

    def _insert_scatter(
        mut self,
        var scatter: ScatterSeries,
        var label: String,
        style: SeriesStyle,
    ):
        var index = len(self._scatters)
        self._scatters.append(scatter^)
        self._scatter_labels.append(label^)
        self._scatter_styles.append(style)
        self._order.append(_SeriesOrder(_SeriesKind.SCATTER, index))

    def add_line(
        mut self,
        var line: LineSeries,
        style: SeriesStyle = SeriesStyle(),
        *,
        var label: String = String(),
    ):
        """Take ownership and store ``label`` in insertion order.

        The label is empty by default. This performs no validation and never
        raises.
        """
        self._insert_line(line^, label^, style)

    def add_scatter(
        mut self,
        var scatter: ScatterSeries,
        style: SeriesStyle = SeriesStyle(),
        *,
        var label: String = String(),
    ):
        """Take ownership and store ``label`` in insertion order.

        The label is empty by default. This performs no validation and never
        raises.
        """
        self._insert_scatter(scatter^, label^, style)

    def line(
        mut self,
        x: Span[Float64, ImmutAnyOrigin],
        y: Span[Float64, ImmutAnyOrigin],
        *,
        var label: String = String(),
        style: SeriesStyle = SeriesStyle(),
        missing: MissingPolicy = MissingPolicy.ERROR,
    ) raises:
        """Build and insert a line deterministically from index zero.

        Raises before insertion for unequal lengths, non-NaN infinities, or the
        first NaN under ``MissingPolicy.ERROR``. ``SEGMENT`` creates deterministic
        gaps and ``DROP`` joins the remaining finite points.
        """
        var series = LineSeries._from_xy_missing(x, y, missing)
        self._insert_line(series^, label^, style)

    def scatter(
        mut self,
        x: Span[Float64, ImmutAnyOrigin],
        y: Span[Float64, ImmutAnyOrigin],
        *,
        var label: String = String(),
        style: SeriesStyle = SeriesStyle(),
        missing: MissingPolicy = MissingPolicy.ERROR,
    ) raises:
        """Build and insert markers using the requested missing-data policy.

        Because disconnected topology has no meaning for markers, ``SEGMENT``
        behaves identically to ``DROP``. ``ERROR`` still rejects the first NaN.
        A ``MarkerStyle.NONE`` style falls back to ``CIRCLE`` at render time so
        the marker-only series remains visible. Unequal lengths and non-NaN
        infinities raise before insertion; accepted markers preserve input order
        deterministically.
        """
        var series = ScatterSeries._from_xy_missing(x, y, missing)
        self._insert_scatter(series^, label^, style)

    def set_title(mut self, var title: String):
        """Set title text exactly and deterministically without raising."""
        self._title = title^

    def set_x_label(mut self, var label: String):
        """Set x-axis label text exactly and deterministically without raising."""
        self._x_label = label^

    def set_y_label(mut self, var label: String):
        """Set y-axis label text exactly and deterministically without raising."""
        self._y_label = label^

    def set_legend(mut self, position: LegendPosition):
        """Set deterministic legend placement without validation or raising."""
        self._legend_position = position

    def set_grid(mut self, enabled: Bool):
        """Enable or disable deterministic major gridlines without raising."""
        self._grid_enabled = enabled

    def set_x_scale(mut self, scale: AxisKind):
        """Select x mapping without raising; LOG10 positivity is render-checked."""
        self._x_scale = scale

    def set_y_scale(mut self, scale: AxisKind):
        """Select y mapping without raising; LOG10 positivity is render-checked."""
        self._y_scale = scale

    def set_x_limits(mut self, lo: Float64, hi: Float64) raises:
        """Set an exact deterministic x domain; reject non-finite or lo >= hi."""
        if not isfinite(lo) or not isfinite(hi):
            raise Error("x limits must be finite; got lo = ", lo, ", hi = ", hi)
        if lo >= hi:
            raise Error("x limits must satisfy lo < hi; got lo = ", lo, ", hi = ", hi)
        self._has_x_limits = True
        self._x_limit_lo = lo
        self._x_limit_hi = hi

    def set_y_limits(mut self, lo: Float64, hi: Float64) raises:
        """Set an exact deterministic y domain; reject non-finite or lo >= hi."""
        if not isfinite(lo) or not isfinite(hi):
            raise Error("y limits must be finite; got lo = ", lo, ", hi = ", hi)
        if lo >= hi:
            raise Error("y limits must satisfy lo < hi; got lo = ", lo, ", hi = ", hi)
        self._has_y_limits = True
        self._y_limit_lo = lo
        self._y_limit_hi = hi

    def title(self) -> ref[self._title] String:
        """Return the exact stored title by read reference without raising."""
        return self._title

    def x_label(self) -> ref[self._x_label] String:
        """Return the exact stored x label by read reference without raising."""
        return self._x_label

    def y_label(self) -> ref[self._y_label] String:
        """Return the exact stored y label by read reference without raising."""
        return self._y_label

    def legend_position(self) -> LegendPosition:
        """Return deterministic legend placement without raising."""
        return self._legend_position

    def grid_enabled(self) -> Bool:
        """Return the stored major-grid flag without raising."""
        return self._grid_enabled

    def x_scale(self) -> AxisKind:
        """Return the x-axis transform selection without data validation."""
        return self._x_scale

    def y_scale(self) -> AxisKind:
        """Return the y-axis transform selection without data validation."""
        return self._y_scale

    def x_limits(self) -> Optional[Tuple[Float64, Float64]]:
        """Return the exact x override or deterministic absence without raising."""
        if self._has_x_limits:
            return (self._x_limit_lo, self._x_limit_hi)
        return None

    def y_limits(self) -> Optional[Tuple[Float64, Float64]]:
        """Return the exact y override or deterministic absence without raising."""
        if self._has_y_limits:
            return (self._y_limit_lo, self._y_limit_hi)
        return None

    def validate(self) raises:
        """Validate all stored invariants in deterministic field and index order."""
        if self._has_x_limits:
            if not isfinite(self._x_limit_lo) or not isfinite(self._x_limit_hi):
                raise Error(
                    "x limits must be finite; got lo = ",
                    self._x_limit_lo,
                    ", hi = ",
                    self._x_limit_hi,
                )
            if self._x_limit_lo >= self._x_limit_hi:
                raise Error(
                    "x limits must satisfy lo < hi; got lo = ",
                    self._x_limit_lo,
                    ", hi = ",
                    self._x_limit_hi,
                )
        if self._has_y_limits:
            if not isfinite(self._y_limit_lo) or not isfinite(self._y_limit_hi):
                raise Error(
                    "y limits must be finite; got lo = ",
                    self._y_limit_lo,
                    ", hi = ",
                    self._y_limit_hi,
                )
            if self._y_limit_lo >= self._y_limit_hi:
                raise Error(
                    "y limits must satisfy lo < hi; got lo = ",
                    self._y_limit_lo,
                    ", hi = ",
                    self._y_limit_hi,
                )
        for index in range(len(self._lines)):
            self._lines[index].validate()
        for index in range(len(self._scatters)):
            self._scatters[index].validate()
        for index in range(len(self._line_styles)):
            self._line_styles[index].validate()
        for index in range(len(self._scatter_styles)):
            self._scatter_styles[index].validate()
        if len(self._line_labels) != len(self._lines):
            raise Error(
                "figure line labels must match stored line series; got ",
                len(self._line_labels),
                " labels for ",
                len(self._lines),
                " series",
            )
        if len(self._line_styles) != len(self._lines):
            raise Error(
                "figure line styles must match stored line series; got ",
                len(self._line_styles),
                " styles for ",
                len(self._lines),
                " series",
            )
        if len(self._scatter_labels) != len(self._scatters):
            raise Error(
                "figure scatter labels must match stored scatter series; got ",
                len(self._scatter_labels),
                " labels for ",
                len(self._scatters),
                " series",
            )
        if len(self._scatter_styles) != len(self._scatters):
            raise Error(
                "figure scatter styles must match stored scatter series; got ",
                len(self._scatter_styles),
                " styles for ",
                len(self._scatters),
                " series",
            )
        if len(self._order) != len(self._lines) + len(self._scatters):
            raise Error(
                "figure series order must include every stored series; got ",
                len(self._order),
                " order entries for ",
                len(self._lines) + len(self._scatters),
                " series",
            )

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
                    raise Error(
                        "figure line order index must be within [0, ",
                        len(self._lines),
                        "); got ",
                        entry.index,
                    )
                if seen_lines[entry.index]:
                    raise Error("figure series order must not contain duplicates")
                seen_lines[entry.index] = True
            elif entry.kind._value == _SeriesKind.SCATTER._value:
                if entry.index < 0 or entry.index >= len(self._scatters):
                    raise Error(
                        "figure scatter order index must be within [0, ",
                        len(self._scatters),
                        "); got ",
                        entry.index,
                    )
                if seen_scatters[entry.index]:
                    raise Error("figure series order must not contain duplicates")
                seen_scatters[entry.index] = True
            else:
                raise Error("figure series order contains an unknown kind")

    def is_empty(self) -> Bool:
        """Return whether no series are stored; this check never raises."""
        return len(self._lines) == 0 and len(self._scatters) == 0

    def line_count(self) -> Int:
        """Return the deterministic stored line count without raising."""
        return len(self._lines)

    def scatter_count(self) -> Int:
        """Return the deterministic stored scatter count without raising."""
        return len(self._scatters)

    def bounds(self) raises -> DataBounds:
        """Return combined bounds for every nonempty line and scatter series.

        Empty series do not contribute an extent. A figure with no series and a
        figure whose series are all empty are rejected with distinct guidance.
        Bounds are combined in stable line-then-scatter storage order.
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
            var series_count = len(self._lines) + len(self._scatters)
            if series_count == 0:
                raise Error(
                    "figure has no series; add data with line() or scatter() "
                    "before rendering"
                )
            raise Error(
                "figure has ",
                series_count,
                " series but all are empty; add points before rendering",
            )
        return combined.value()

    def line(self, index: Int) raises -> ref[self._lines[index]] LineSeries:
        """Return a stable read reference; reject an out-of-range line index."""
        if index < 0 or index >= len(self._lines):
            raise Error(
                "figure line index must be within [0, ",
                len(self._lines),
                "); got ",
                index,
            )
        return self._lines[index]

    def scatter(self, index: Int) raises -> ref[self._scatters[index]] ScatterSeries:
        """Return a stable read reference; reject an out-of-range scatter index."""
        if index < 0 or index >= len(self._scatters):
            raise Error(
                "figure scatter index must be within [0, ",
                len(self._scatters),
                "); got ",
                index,
            )
        return self._scatters[index]

    def line_label(self, index: Int) raises -> ref[self._line_labels[index]] String:
        """Return the exact label; reject an out-of-range line position."""
        if index < 0 or index >= len(self._line_labels):
            raise Error(
                "figure line-label index must be within [0, ",
                len(self._line_labels),
                "); got ",
                index,
            )
        return self._line_labels[index]

    def scatter_label(
        self, index: Int
    ) raises -> ref[self._scatter_labels[index]] String:
        """Return the exact label; reject an out-of-range scatter position."""
        if index < 0 or index >= len(self._scatter_labels):
            raise Error(
                "figure scatter-label index must be within [0, ",
                len(self._scatter_labels),
                "); got ",
                index,
            )
        return self._scatter_labels[index]

    def _series_count(self) -> Int:
        return len(self._order)

    def _series_is_line(self, index: Int) -> Bool:
        return self._order[index].kind._value == _SeriesKind.LINE._value

    def _series_index(self, index: Int) -> Int:
        return self._order[index].index

    def _series_style(self, index: Int) -> SeriesStyle:
        ref entry = self._order[index]
        if entry.kind._value == _SeriesKind.LINE._value:
            return self._line_styles[entry.index]
        return self._scatter_styles[entry.index]

    def _series_label(self, index: Int) -> String:
        ref entry = self._order[index]
        if entry.kind._value == _SeriesKind.LINE._value:
            return self._line_labels[entry.index].copy()
        return self._scatter_labels[entry.index].copy()

    def save_svg(
        self,
        path: StringSlice,
        width: Float64 = 640.0,
        height: Float64 = 480.0,
    ) raises:
        """Render at the requested size and save it deterministically.

        Missing parent directories are created. Rendering and I/O errors
        propagate to the caller.
        """
        from .svg import render_svg, save_svg

        var svg = render_svg(self, width, height)
        save_svg(path, svg)
