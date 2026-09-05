"""Renderer-independent plotting-series semantics."""

from std.collections import List, Optional
from std.math import isfinite
from std.sys import simd_width_of

from .figure_config import FigureConfig
from .layout import Margins
from .style import SeriesStyle
from .text import Text, TextKind
from .theme import Theme
from .typst import TypstOptions


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

    def validate(self) raises:
        """Reject discriminants outside Sen's missing-data vocabulary."""
        if self._value < 0 or self._value > 2:
            raise Error("missing policy is outside Sen's vocabulary")


struct StepMode(Copyable, Equatable, ImplicitlyCopyable):
    """Choose where a step line changes between adjacent observations."""

    var _value: Int

    comptime PRE = StepMode(_value=0)
    comptime POST = StepMode(_value=1)
    comptime MID = StepMode(_value=2)

    def __init__(out self, *, _value: Int):
        """Construct a mode discriminant for library-defined constants."""
        self._value = _value

    def __eq__(self, other: Self) -> Bool:
        """Return whether both values select the same step placement."""
        return self._value == other._value

    def validate(self) raises:
        """Reject discriminants outside Sen's step-placement vocabulary."""
        if self._value < 0 or self._value > 2:
            raise Error("step mode is outside Sen's vocabulary")


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
        x: Span[mut=False, Float64, ...],
        y: Span[mut=False, Float64, ...],
    ) raises -> Self:
        """Build a series from coordinate spans using the bulk-data fast path.

        ``List[Float64]`` values convert implicitly to the accepted span shape;
        mutable or immutable subspans are borrowed read-only for this call.
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
        missing.validate()
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

    @staticmethod
    def _step(
        x: Span[Float64, ImmutAnyOrigin],
        y: Span[Float64, ImmutAnyOrigin],
        mode: StepMode,
    ) raises -> Self:
        """Lower finite observations into one allocation-sized step line."""
        mode.validate()
        if len(x) != len(y):
            raise Error(
                "step x length ",
                len(x),
                " must equal y length ",
                len(y),
                "; pass one y value per x value",
            )
        var capacity = 0
        if len(x) > 0:
            capacity = 2 * len(x) - 1
            if mode == StepMode.MID:
                capacity = 2 * len(x)
        var xs = List[Float64](capacity=capacity)
        var ys = List[Float64](capacity=capacity)
        var segment_starts = List[Int]()
        if len(x) == 0:
            return Self(xs^, ys^, segment_starts^, _validated=_Validated())
        segment_starts.append(0)
        for index in range(len(x)):
            var x_coordinate = x[index]
            var y_coordinate = y[index]
            if not isfinite(x_coordinate):
                raise Error(
                    "step x at index ",
                    index,
                    " must be finite; got ",
                    x_coordinate,
                    "; remove or replace the invalid coordinate",
                )
            if not isfinite(y_coordinate):
                raise Error(
                    "step y at index ",
                    index,
                    " must be finite; got ",
                    y_coordinate,
                    "; remove or replace the invalid coordinate",
                )
        if mode == StepMode.PRE:
            for index in range(len(x)):
                xs.append(x[index])
                ys.append(y[index])
                if index + 1 < len(x):
                    xs.append(x[index])
                    ys.append(y[index + 1])
        elif mode == StepMode.POST:
            for index in range(len(x)):
                xs.append(x[index])
                ys.append(y[index])
                if index + 1 < len(x):
                    xs.append(x[index + 1])
                    ys.append(y[index])
        else:
            xs.append(x[0])
            ys.append(y[0])
            for index in range(len(x) - 1):
                # Half before addition avoids overflow for same-sign finite
                # endpoints near the limits of Float64.
                var midpoint = x[index] / 2.0 + x[index + 1] / 2.0
                xs.append(midpoint)
                ys.append(y[index])
                xs.append(midpoint)
                ys.append(y[index + 1])
            if len(x) > 1:
                xs.append(x[len(x) - 1])
                ys.append(y[len(y) - 1])
        return Self(xs^, ys^, segment_starts^, _validated=_Validated())

    @staticmethod
    def _stems(
        x: Span[Float64, ImmutAnyOrigin],
        y: Span[Float64, ImmutAnyOrigin],
        baseline: Float64,
    ) raises -> Self:
        """Lower vertical stems into one segmented line-series."""
        if len(x) != len(y):
            raise Error(
                "stem x length ",
                len(x),
                " must equal y length ",
                len(y),
                "; pass one y value per x value",
            )
        if not isfinite(baseline):
            raise Error(
                "stem baseline must be finite; got ",
                baseline,
                "; pass a finite baseline",
            )
        var xs = List[Float64](capacity=2 * len(x))
        var ys = List[Float64](capacity=2 * len(x))
        var segment_starts = List[Int](capacity=len(x))
        for index in range(len(x)):
            if not isfinite(x[index]) or not isfinite(y[index]):
                raise Error(
                    "stem coordinates at index ",
                    index,
                    " must be finite; got x = ",
                    x[index],
                    ", y = ",
                    y[index],
                    "; remove or replace the invalid observation",
                )
            segment_starts.append(len(xs))
            xs.append(x[index])
            ys.append(baseline)
            xs.append(x[index])
            ys.append(y[index])
        return Self(xs^, ys^, segment_starts^, _validated=_Validated())

    @staticmethod
    def _errorbars(
        x: Span[Float64, ...],
        y: Span[Float64, ...],
        x_error: Span[Float64, ...],
        y_error: Span[Float64, ...],
        has_x_error: Bool,
        has_y_error: Bool,
        cap_size: Float64,
    ) raises -> Self:
        """Lower symmetric x/y error extents into one segmented line-series."""
        if len(x) != len(y):
            raise Error(
                "errorbar x length ",
                len(x),
                " must equal y length ",
                len(y),
                "; pass one y value per x value",
            )
        if has_x_error and len(x_error) != len(x):
            raise Error(
                "x_error length ",
                len(x_error),
                " must equal coordinate length ",
                len(x),
                "; pass one symmetric x error per observation",
            )
        if has_y_error and len(y_error) != len(x):
            raise Error(
                "y_error length ",
                len(y_error),
                " must equal coordinate length ",
                len(x),
                "; pass one symmetric y error per observation",
            )
        if not isfinite(cap_size) or cap_size < 0.0:
            raise Error(
                "errorbar cap_size must be finite and non-negative; got ",
                cap_size,
                "; pass cap_size >= 0",
            )
        var segments_per_point = 0
        if has_x_error:
            segments_per_point += 1
            if cap_size > 0.0:
                segments_per_point += 2
        if has_y_error:
            segments_per_point += 1
            if cap_size > 0.0:
                segments_per_point += 2
        var point_capacity = 2 * segments_per_point * len(x)
        var xs = List[Float64](capacity=point_capacity)
        var ys = List[Float64](capacity=point_capacity)
        var segment_starts = List[Int](capacity=segments_per_point * len(x))
        var half_cap = cap_size / 2.0

        for index in range(len(x)):
            var center_x = x[index]
            var center_y = y[index]
            if not isfinite(center_x) or not isfinite(center_y):
                raise Error(
                    "errorbar coordinates at index ",
                    index,
                    " must be finite; got x = ",
                    center_x,
                    ", y = ",
                    center_y,
                    "; remove or replace the invalid observation",
                )
            if has_x_error:
                var error = x_error[index]
                if not isfinite(error) or error < 0.0:
                    raise Error(
                        "x_error at index ",
                        index,
                        " must be finite and non-negative; got ",
                        error,
                        "; pass an absolute symmetric error",
                    )
                var left = center_x - error
                var right = center_x + error
                if not isfinite(left) or not isfinite(right):
                    raise Error(
                        "x_error at index ",
                        index,
                        " produces non-finite endpoints; got center = ",
                        center_x,
                        ", error = ",
                        error,
                        "; reduce the error magnitude",
                    )
                segment_starts.append(len(xs))
                xs.append(left)
                ys.append(center_y)
                xs.append(right)
                ys.append(center_y)
                if cap_size > 0.0:
                    segment_starts.append(len(xs))
                    xs.append(left)
                    ys.append(center_y - half_cap)
                    xs.append(left)
                    ys.append(center_y + half_cap)
                    segment_starts.append(len(xs))
                    xs.append(right)
                    ys.append(center_y - half_cap)
                    xs.append(right)
                    ys.append(center_y + half_cap)
            if has_y_error:
                var error = y_error[index]
                if not isfinite(error) or error < 0.0:
                    raise Error(
                        "y_error at index ",
                        index,
                        " must be finite and non-negative; got ",
                        error,
                        "; pass an absolute symmetric error",
                    )
                var lower = center_y - error
                var upper = center_y + error
                if not isfinite(lower) or not isfinite(upper):
                    raise Error(
                        "y_error at index ",
                        index,
                        " produces non-finite endpoints; got center = ",
                        center_y,
                        ", error = ",
                        error,
                        "; reduce the error magnitude",
                    )
                segment_starts.append(len(xs))
                xs.append(center_x)
                ys.append(lower)
                xs.append(center_x)
                ys.append(upper)
                if cap_size > 0.0:
                    segment_starts.append(len(xs))
                    xs.append(center_x - half_cap)
                    ys.append(lower)
                    xs.append(center_x + half_cap)
                    ys.append(lower)
                    segment_starts.append(len(xs))
                    xs.append(center_x - half_cap)
                    ys.append(upper)
                    xs.append(center_x + half_cap)
                    ys.append(upper)
        for index in range(len(xs)):
            if not isfinite(xs[index]) or not isfinite(ys[index]):
                raise Error(
                    "errorbar cap_size produces non-finite endpoints; got ",
                    cap_size,
                    "; reduce cap_size",
                )
        return Self(xs^, ys^, segment_starts^, _validated=_Validated())

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
        missing.validate()
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


struct AreaSeries(Copyable):
    """One or more finite line segments filled to a constant y baseline.

    The boundary topology is exactly ``LineSeries`` topology, so missing-value
    segmentation remains explicit and renderer-neutral. The finite baseline is
    included in bounds only when the series contains a point.
    """

    var _boundary: LineSeries
    var _baseline: Float64

    def __init__(out self, var boundary: LineSeries, baseline: Float64) raises:
        self._boundary = boundary^
        self._baseline = baseline
        self.validate()

    @staticmethod
    def from_xy(
        x: Span[Float64, ImmutAnyOrigin],
        y: Span[Float64, ImmutAnyOrigin],
        *,
        baseline: Float64 = 0.0,
        missing: MissingPolicy = MissingPolicy.ERROR,
    ) raises -> Self:
        """Build a segmented area boundary atomically from coordinate spans."""
        if not isfinite(baseline):
            raise Error("area baseline must be finite; got ", baseline)
        var boundary = LineSeries._from_xy_missing(x, y, missing)
        return Self(boundary^, baseline)

    def validate(self) raises:
        """Validate the boundary topology and finite baseline."""
        self._boundary.validate()
        if not isfinite(self._baseline):
            raise Error("area baseline must be finite; got ", self._baseline)

    def is_empty(self) -> Bool:
        return self._boundary.is_empty()

    def point_count(self) -> Int:
        return self._boundary.point_count()

    def segment_count(self) -> Int:
        return self._boundary.segment_count()

    def segment_point_count(self, segment_index: Int) raises -> Int:
        return self._boundary.segment_point_count(segment_index)

    def segment_point(self, segment_index: Int, point_index: Int) raises -> PlotPoint:
        return self._boundary.segment_point(segment_index, point_index)

    def baseline(self) -> Float64:
        return self._baseline

    def bounds(self) raises -> DataBounds:
        """Return boundary bounds expanded vertically to the baseline."""
        var bounds = self._boundary.bounds()
        return DataBounds._from_validated(
            bounds._x_min,
            bounds._x_max,
            min(bounds._y_min, self._baseline),
            max(bounds._y_max, self._baseline),
        )


struct DataRectangle(Copyable, ImplicitlyCopyable):
    """One validated axis-aligned rectangle in data coordinates."""

    var _left: Float64
    var _right: Float64
    var _bottom: Float64
    var _top: Float64

    def __init__(
        out self,
        left: Float64,
        right: Float64,
        bottom: Float64,
        top: Float64,
    ) raises:
        self._left = left
        self._right = right
        self._bottom = bottom
        self._top = top
        self.validate()

    @staticmethod
    def _from_validated(
        left: Float64,
        right: Float64,
        bottom: Float64,
        top: Float64,
    ) -> Self:
        return Self(left, right, bottom, top, _validated=_Validated())

    def __init__(
        out self,
        left: Float64,
        right: Float64,
        bottom: Float64,
        top: Float64,
        *,
        _validated: _Validated,
    ):
        self._left = left
        self._right = right
        self._bottom = bottom
        self._top = top

    def validate(self) raises:
        """Validate finite, ordered data-space edges explicitly."""
        if (
            not isfinite(self._left)
            or not isfinite(self._right)
            or not isfinite(self._bottom)
            or not isfinite(self._top)
        ):
            raise Error(
                "rectangle edges must be finite; got left = ",
                self._left,
                ", right = ",
                self._right,
                ", bottom = ",
                self._bottom,
                ", top = ",
                self._top,
                "; pass finite edges",
            )
        if self._left > self._right:
            raise Error(
                "rectangle left must not exceed right; got left = ",
                self._left,
                ", right = ",
                self._right,
                "; order the horizontal edges",
            )
        if self._bottom > self._top:
            raise Error(
                "rectangle bottom must not exceed top; got bottom = ",
                self._bottom,
                ", top = ",
                self._top,
                "; order the vertical edges",
            )

    def left(self) -> Float64:
        return self._left

    def right(self) -> Float64:
        return self._right

    def bottom(self) -> Float64:
        return self._bottom

    def top(self) -> Float64:
        return self._top


struct RectangleSeries(Copyable):
    """A reusable filled-rectangle primitive with SoA data-space storage.

    Construction establishes equal-length, finite, ordered edge buffers. Direct
    mutation of underscore-prefixed storage is out of contract; call
    ``validate`` explicitly after unusual low-level mutation.
    """

    var _lefts: List[Float64]
    var _rights: List[Float64]
    var _bottoms: List[Float64]
    var _tops: List[Float64]

    def __init__(out self):
        self._lefts = List[Float64]()
        self._rights = List[Float64]()
        self._bottoms = List[Float64]()
        self._tops = List[Float64]()

    def __init__(
        out self,
        var lefts: List[Float64],
        var rights: List[Float64],
        var bottoms: List[Float64],
        var tops: List[Float64],
        *,
        _validated: _Validated,
    ):
        self._lefts = lefts^
        self._rights = rights^
        self._bottoms = bottoms^
        self._tops = tops^

    @staticmethod
    def from_edges(
        left: Span[Float64, ...],
        right: Span[Float64, ...],
        bottom: Span[Float64, ...],
        top: Span[Float64, ...],
    ) raises -> Self:
        """Build rectangles from equal-length edge spans in one pass."""
        if len(left) != len(right) or len(left) != len(bottom) or len(left) != len(top):
            raise Error(
                "rectangle edge lengths must all equal left length ",
                len(left),
                "; got right = ",
                len(right),
                ", bottom = ",
                len(bottom),
                ", top = ",
                len(top),
            )
        var lefts = List[Float64](capacity=len(left))
        var rights = List[Float64](capacity=len(left))
        var bottoms = List[Float64](capacity=len(left))
        var tops = List[Float64](capacity=len(left))
        for index in range(len(left)):
            var rectangle = DataRectangle(
                left[index], right[index], bottom[index], top[index]
            )
            lefts.append(rectangle.left())
            rights.append(rectangle.right())
            bottoms.append(rectangle.bottom())
            tops.append(rectangle.top())
        return Self(
            lefts^,
            rights^,
            bottoms^,
            tops^,
            _validated=_Validated(),
        )

    def append(mut self, rectangle: DataRectangle) raises:
        """Append one validated rectangle after an explicit checkpoint."""
        rectangle.validate()
        self._lefts.append(rectangle.left())
        self._rights.append(rectangle.right())
        self._bottoms.append(rectangle.bottom())
        self._tops.append(rectangle.top())

    @staticmethod
    def _bars(
        x: Span[Float64, ...],
        height: Span[Float64, ...],
        width: Float64,
        baseline: Float64,
    ) raises -> Self:
        if len(x) != len(height):
            raise Error(
                "bar x length ",
                len(x),
                " must equal height length ",
                len(height),
                "; pass one height per x position",
            )
        if not isfinite(width) or width <= 0.0:
            raise Error(
                "bar width must be finite and positive; got ",
                width,
                "; pass width > 0",
            )
        if not isfinite(baseline):
            raise Error(
                "bar baseline must be finite; got ",
                baseline,
                "; pass a finite baseline",
            )
        var lefts = List[Float64](capacity=len(x))
        var rights = List[Float64](capacity=len(x))
        var bottoms = List[Float64](capacity=len(x))
        var tops = List[Float64](capacity=len(x))
        var half_width = width / 2.0
        for index in range(len(x)):
            var center = x[index]
            var value = height[index]
            var left = center - half_width
            var right = center + half_width
            var endpoint = baseline + value
            if (
                not isfinite(center)
                or not isfinite(value)
                or not isfinite(left)
                or not isfinite(right)
                or not isfinite(endpoint)
            ):
                raise Error(
                    "bar at index ",
                    index,
                    " must produce finite edges; got x = ",
                    center,
                    ", height = ",
                    value,
                    ", baseline = ",
                    baseline,
                    ", width = ",
                    width,
                    "; replace the value or reduce its magnitude or width",
                )
            lefts.append(left)
            rights.append(right)
            bottoms.append(min(baseline, endpoint))
            tops.append(max(baseline, endpoint))
        return Self(
            lefts^,
            rights^,
            bottoms^,
            tops^,
            _validated=_Validated(),
        )

    @staticmethod
    def _categorical_bars(
        height: Span[Float64, ...],
        width: Float64,
        baseline: Float64,
    ) raises -> Self:
        if not isfinite(width) or width <= 0.0:
            raise Error(
                "bar width must be finite and positive; got ",
                width,
                "; pass width > 0",
            )
        if not isfinite(baseline):
            raise Error(
                "bar baseline must be finite; got ",
                baseline,
                "; pass a finite baseline",
            )
        var lefts = List[Float64](capacity=len(height))
        var rights = List[Float64](capacity=len(height))
        var bottoms = List[Float64](capacity=len(height))
        var tops = List[Float64](capacity=len(height))
        var half_width = width / 2.0
        for index in range(len(height)):
            var value = height[index]
            var endpoint = baseline + value
            if not isfinite(value) or not isfinite(endpoint):
                raise Error(
                    "bar height at index ",
                    index,
                    " must produce a finite endpoint from baseline; got height = ",
                    value,
                    ", baseline = ",
                    baseline,
                    "; replace the invalid value",
                )
            lefts.append(Float64(index) - half_width)
            rights.append(Float64(index) + half_width)
            bottoms.append(min(baseline, endpoint))
            tops.append(max(baseline, endpoint))
        return Self(
            lefts^,
            rights^,
            bottoms^,
            tops^,
            _validated=_Validated(),
        )

    @staticmethod
    def _histogram(
        data: Span[Float64, ...],
        bins: Int,
        has_range: Bool,
        requested_lo: Float64,
        requested_hi: Float64,
    ) raises -> Self:
        if bins <= 0:
            raise Error(
                "histogram bin count must be positive; got ",
                bins,
                "; pass bins >= 1",
            )
        if len(data) == 0:
            raise Error(
                (
                    "histogram data must contain at least one finite value; got length"
                    " 0; pass a nonempty sample"
                ),
            )
        if has_range and (
            not isfinite(requested_lo)
            or not isfinite(requested_hi)
            or requested_lo >= requested_hi
        ):
            raise Error(
                "histogram range must contain finite lo < hi; got lo = ",
                requested_lo,
                ", hi = ",
                requested_hi,
                "; pass an ordered finite range",
            )

        var data_lo = Float64.MAX_FINITE
        var data_hi = -Float64.MAX_FINITE
        comptime simd_width = simd_width_of[DType.float64]()
        var vector_end = len(data) - len(data) % simd_width
        var data_ptr = data.unsafe_ptr()
        for offset in range(0, vector_end, simd_width):
            # Safety: vector_end is rounded down to a whole native SIMD width,
            # so every load stays within the borrowed contiguous span. The
            # pointer does not escape this validation-and-reduction scope.
            var values = data_ptr.unsafe_load[width=simd_width](offset)
            var finite_mask = isfinite(values)
            if finite_mask != SIMD[DType.bool, simd_width](fill=True):
                for lane in range(simd_width):
                    var index = offset + lane
                    var value = data[index]
                    if not isfinite(value):
                        raise Error(
                            "histogram data at index ",
                            index,
                            " must be finite; got ",
                            value,
                            "; remove or replace the invalid sample",
                        )
            data_lo = min(data_lo, values.reduce_min())
            data_hi = max(data_hi, values.reduce_max())
        for index in range(vector_end, len(data)):
            var value = data[index]
            if not isfinite(value):
                raise Error(
                    "histogram data at index ",
                    index,
                    " must be finite; got ",
                    value,
                    "; remove or replace the invalid sample",
                )
            data_lo = min(data_lo, value)
            data_hi = max(data_hi, value)

        var lo = requested_lo if has_range else data_lo
        var hi = requested_hi if has_range else data_hi
        if not has_range and lo == hi:
            var padding = max(abs(lo) * 0.1, 1.0)
            if lo > 0.0 and not isfinite(lo + padding):
                hi = lo
                lo -= padding
            elif lo < 0.0 and not isfinite(lo - padding):
                hi = lo + padding
            else:
                lo -= padding
                hi += padding

        var lefts = List[Float64](capacity=bins)
        var rights = List[Float64](capacity=bins)
        var bottoms = List[Float64](capacity=bins)
        var tops = List[Float64](capacity=bins)
        for index in range(bins):
            var left_fraction = Float64(index) / Float64(bins)
            var right_fraction = Float64(index + 1) / Float64(bins)
            var left = (1.0 - left_fraction) * lo + left_fraction * hi
            var right = (1.0 - right_fraction) * lo + right_fraction * hi
            if not isfinite(left) or not isfinite(right) or left >= right:
                raise Error(
                    "histogram range [",
                    lo,
                    ", ",
                    hi,
                    "] is too narrow for ",
                    bins,
                    " distinct bins; reduce the bin count or widen the range",
                )
            lefts.append(left)
            rights.append(right)
            bottoms.append(0.0)
            tops.append(0.0)

        var scale = max(abs(lo), abs(hi))
        for index in range(len(data)):
            var value = data[index]
            if value < lo or value > hi:
                continue
            var bin_index = bins - 1
            if value != hi:
                var span = hi - lo
                var position: Float64
                if isfinite(span):
                    position = (value - lo) / span
                else:
                    # Scaling all terms first avoids overflow for a finite range
                    # spanning large opposite-sign magnitudes.
                    position = (value / scale - lo / scale) / (hi / scale - lo / scale)
                bin_index = max(0, min(Int(position * Float64(bins)), bins - 1))
                # The arithmetic estimate and the interpolated stored boundary
                # can round in opposite directions for offset ranges. Correct
                # against the exact rendered edges so an interior boundary is
                # always assigned to its left-inclusive bin.
                if bin_index > 0 and value < lefts[bin_index]:
                    bin_index -= 1
                elif bin_index < bins - 1 and value >= rights[bin_index]:
                    bin_index += 1
            tops[bin_index] += 1.0
        return Self(
            lefts^,
            rights^,
            bottoms^,
            tops^,
            _validated=_Validated(),
        )

    def validate(self) raises:
        """Validate buffer lengths and every rectangle in stable order."""
        if (
            len(self._lefts) != len(self._rights)
            or len(self._lefts) != len(self._bottoms)
            or len(self._lefts) != len(self._tops)
        ):
            raise Error("rectangle-series edge buffers must have equal length")
        for index in range(len(self._lefts)):
            DataRectangle._from_validated(
                self._lefts[index],
                self._rights[index],
                self._bottoms[index],
                self._tops[index],
            ).validate()

    def is_empty(self) -> Bool:
        return len(self._lefts) == 0

    def rectangle_count(self) -> Int:
        return len(self._lefts)

    def rectangle(self, index: Int) raises -> DataRectangle:
        if index < 0 or index >= len(self._lefts):
            raise Error(
                "rectangle-series index must be within [0, ",
                len(self._lefts),
                "); got ",
                index,
            )
        return DataRectangle._from_validated(
            self._lefts[index],
            self._rights[index],
            self._bottoms[index],
            self._tops[index],
        )

    def bounds(self) raises -> DataBounds:
        if self.is_empty():
            raise Error("empty rectangle-series has no data bounds")
        var x_min = self._lefts[0]
        var x_max = self._rights[0]
        var y_min = self._bottoms[0]
        var y_max = self._tops[0]
        for index in range(1, len(self._lefts)):
            x_min = min(x_min, self._lefts[index])
            x_max = max(x_max, self._rights[index])
            y_min = min(y_min, self._bottoms[index])
            y_max = max(y_max, self._tops[index])
        return DataBounds._from_validated(x_min, x_max, y_min, y_max)


struct _SeriesKind(Copyable, ImplicitlyCopyable):
    var _value: Int

    comptime LINE = _SeriesKind(_value=0)
    comptime SCATTER = _SeriesKind(_value=1)
    comptime RECTANGLE = _SeriesKind(_value=2)
    comptime AREA = _SeriesKind(_value=3)

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

    def validate(self) raises:
        """Reject discriminants outside Sen's axis-kind vocabulary."""
        if self._value < 0 or self._value > 1:
            raise Error("axis kind is outside Sen's vocabulary")


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
    comptime BEST = LegendPosition(_value=5)

    def __init__(out self, *, _value: Int):
        """Construct a position discriminant for library-defined constants."""
        self._value = _value

    def __eq__(self, other: Self) -> Bool:
        """Return deterministic discriminant equality without raising."""
        return self._value == other._value

    def validate(self) raises:
        """Reject discriminants outside Sen's legend-position vocabulary."""
        if self._value < 0 or self._value > 5:
            raise Error("legend position is outside Sen's vocabulary")


struct Figure(Copyable):
    """A renderer-neutral collection preserving interleaved series draw order.

    Lower-level ``add_line``, ``add_scatter``, ``add_area``, and
    ``add_rectangles`` calls take ownership without copying and accept optional
    labels. One-call ingestion builds and validates line, marker, segmented
    basic-plot, or filled-rectangle semantics before insertion. Constructed
    series are trusted on insertion and public operations trust them thereafter.
    Direct mutation of
    underscore-prefixed storage is out of contract; call ``validate`` explicitly
    when a checkpoint is needed. All stored ordering, palette, legend, axis, and
    grid state is consumed deterministically by renderers; fallible ingestion,
    limits, lookup, bounds, validation, rendering, and I/O methods document their
    rejection conditions.
    """

    var _lines: List[LineSeries]
    var _line_labels: List[String]
    var _line_styles: List[SeriesStyle]
    var _scatters: List[ScatterSeries]
    var _scatter_labels: List[String]
    var _scatter_styles: List[SeriesStyle]
    var _areas: List[AreaSeries]
    var _area_labels: List[String]
    var _area_styles: List[SeriesStyle]
    var _rectangles: List[RectangleSeries]
    var _rectangle_labels: List[String]
    var _rectangle_styles: List[SeriesStyle]
    var _order: List[_SeriesOrder]
    var _title: String
    var _accessible_description: String
    var _title_kind: TextKind
    var _x_label: String
    var _x_label_kind: TextKind
    var _y_label: String
    var _y_label_kind: TextKind
    var _legend_position: LegendPosition
    var _grid_enabled: Bool
    var _config: FigureConfig
    var _theme: Theme
    var _x_scale: AxisKind
    var _y_scale: AxisKind
    var _has_x_limits: Bool
    var _x_limit_lo: Float64
    var _x_limit_hi: Float64
    var _has_y_limits: Bool
    var _y_limit_lo: Float64
    var _y_limit_hi: Float64
    var _has_x_ticks: Bool
    var _x_tick_positions: List[Float64]
    var _x_tick_labels: List[String]
    var _has_y_ticks: Bool
    var _y_tick_positions: List[Float64]
    var _y_tick_labels: List[String]

    def __init__(out self):
        """Construct deterministic empty linear-axis defaults without raising."""
        self._lines = List[LineSeries]()
        self._line_labels = List[String]()
        self._line_styles = List[SeriesStyle]()
        self._scatters = List[ScatterSeries]()
        self._scatter_labels = List[String]()
        self._scatter_styles = List[SeriesStyle]()
        self._areas = List[AreaSeries]()
        self._area_labels = List[String]()
        self._area_styles = List[SeriesStyle]()
        self._rectangles = List[RectangleSeries]()
        self._rectangle_labels = List[String]()
        self._rectangle_styles = List[SeriesStyle]()
        self._order = List[_SeriesOrder]()
        self._title = String()
        self._accessible_description = String()
        self._title_kind = TextKind.PLAIN
        self._x_label = String()
        self._x_label_kind = TextKind.PLAIN
        self._y_label = String()
        self._y_label_kind = TextKind.PLAIN
        self._legend_position = LegendPosition.BEST
        self._grid_enabled = False
        self._config = FigureConfig()
        self._theme = Theme()
        self._x_scale = AxisKind.LINEAR
        self._y_scale = AxisKind.LINEAR
        self._has_x_limits = False
        self._x_limit_lo = 0.0
        self._x_limit_hi = 1.0
        self._has_y_limits = False
        self._y_limit_lo = 0.0
        self._y_limit_hi = 1.0
        self._has_x_ticks = False
        self._x_tick_positions = List[Float64]()
        self._x_tick_labels = List[String]()
        self._has_y_ticks = False
        self._y_tick_positions = List[Float64]()
        self._y_tick_labels = List[String]()

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

    def _insert_area(
        mut self,
        var area: AreaSeries,
        var label: String,
        style: SeriesStyle,
    ):
        var index = len(self._areas)
        self._areas.append(area^)
        self._area_labels.append(label^)
        self._area_styles.append(style)
        self._order.append(_SeriesOrder(_SeriesKind.AREA, index))

    def _insert_rectangles(
        mut self,
        var rectangles: RectangleSeries,
        var label: String,
        style: SeriesStyle,
    ):
        var index = len(self._rectangles)
        self._rectangles.append(rectangles^)
        self._rectangle_labels.append(label^)
        self._rectangle_styles.append(style)
        self._order.append(_SeriesOrder(_SeriesKind.RECTANGLE, index))

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

    def add_area(
        mut self,
        var area: AreaSeries,
        style: SeriesStyle = SeriesStyle(),
        *,
        var label: String = String(),
    ):
        """Take ownership and store ``label`` in insertion order."""
        self._insert_area(area^, label^, style)

    def add_rectangles(
        mut self,
        var rectangles: RectangleSeries,
        style: SeriesStyle = SeriesStyle(),
        *,
        var label: String = String(),
    ):
        """Take ownership and store ``label`` in insertion order."""
        self._insert_rectangles(rectangles^, label^, style)

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

    def area(
        mut self,
        x: Span[Float64, ImmutAnyOrigin],
        y: Span[Float64, ImmutAnyOrigin],
        *,
        baseline: Float64 = 0.0,
        var label: String = String(),
        style: SeriesStyle = SeriesStyle(),
        missing: MissingPolicy = MissingPolicy.ERROR,
    ) raises:
        """Fill segmented finite observations to a constant y baseline."""
        var series = AreaSeries.from_xy(
            x,
            y,
            baseline=baseline,
            missing=missing,
        )
        self._insert_area(series^, label^, style)

    def step(
        mut self,
        x: Span[Float64, ImmutAnyOrigin],
        y: Span[Float64, ImmutAnyOrigin],
        *,
        mode: StepMode = StepMode.PRE,
        var label: String = String(),
        style: SeriesStyle = SeriesStyle(),
    ) raises:
        """Add one PRE, POST, or MID step line in deterministic input order."""
        var series = LineSeries._step(x, y, mode)
        self._insert_line(series^, label^, style)

    def stem(
        mut self,
        x: Span[Float64, ImmutAnyOrigin],
        y: Span[Float64, ImmutAnyOrigin],
        *,
        baseline: Float64 = 0.0,
        var label: String = String(),
        style: SeriesStyle = SeriesStyle(),
    ) raises:
        """Add vertical stems from ``baseline`` as one segmented line-series."""
        var series = LineSeries._stems(x, y, baseline)
        self._insert_line(series^, label^, style)

    def errorbar(
        mut self,
        x: Span[Float64, ...],
        y: Span[Float64, ...],
        y_error: Span[Float64, ...],
        *,
        cap_size: Float64 = 0.0,
        var label: String = String(),
        style: SeriesStyle = SeriesStyle(),
    ) raises:
        """Add symmetric vertical error bars; ``cap_size`` uses data x units."""
        var no_x_error = List[Float64]()
        var series = LineSeries._errorbars(
            x, y, no_x_error, y_error, False, True, cap_size
        )
        self._insert_line(series^, label^, style)

    def errorbar(
        mut self,
        x: Span[Float64, ...],
        y: Span[Float64, ...],
        x_error: Span[Float64, ...],
        y_error: Span[Float64, ...],
        *,
        cap_size: Float64 = 0.0,
        var label: String = String(),
        style: SeriesStyle = SeriesStyle(),
    ) raises:
        """Add symmetric horizontal and vertical error bars as one series."""
        var series = LineSeries._errorbars(x, y, x_error, y_error, True, True, cap_size)
        self._insert_line(series^, label^, style)

    def bar(
        mut self,
        x: Span[Float64, ...],
        height: Span[Float64, ...],
        *,
        width: Float64 = 0.8,
        baseline: Float64 = 0.0,
        var label: String = String(),
        style: SeriesStyle = SeriesStyle(),
    ) raises:
        """Add filled vertical numeric bars centered on ``x`` positions."""
        var series = RectangleSeries._bars(x, height, width, baseline)
        self._insert_rectangles(series^, label^, style)

    def bar(
        mut self,
        categories: Span[String, _],
        height: Span[Float64, ...],
        *,
        width: Float64 = 0.8,
        baseline: Float64 = 0.0,
        var label: String = String(),
        style: SeriesStyle = SeriesStyle(),
    ) raises:
        """Add filled categorical bars with explicit category tick labels."""
        if len(categories) != len(height):
            raise Error(
                "bar category length ",
                len(categories),
                " must equal height length ",
                len(height),
                "; pass one height per category",
            )
        var series = RectangleSeries._categorical_bars(height, width, baseline)
        if self._has_x_ticks:
            if self.x_tick_count() != len(categories):
                raise Error(
                    "categorical bar domain length ",
                    len(categories),
                    " does not match the existing x tick domain length ",
                    self.x_tick_count(),
                    "; reuse the same categories or start a new plot",
                )
            for index in range(len(categories)):
                if (
                    self._x_tick_positions[index] != Float64(index)
                    or self._x_tick_labels[index] != categories[index]
                ):
                    raise Error(
                        (
                            "categorical bar domain differs from existing x ticks at"
                            " index "
                        ),
                        index,
                        "; reuse the same ordered categories or start a new plot",
                    )
        else:
            var positions = List[Float64](capacity=len(categories))
            var labels = List[String](capacity=len(categories))
            for index in range(len(categories)):
                positions.append(Float64(index))
                labels.append(categories[index].copy())
            self._has_x_ticks = True
            self._x_tick_positions = positions^
            self._x_tick_labels = labels^
        self._insert_rectangles(series^, label^, style)

    def histogram(
        mut self,
        data: Span[Float64, ...],
        *,
        bins: Int = 10,
        var label: String = String(),
        style: SeriesStyle = SeriesStyle(),
    ) raises:
        """Bin finite data into equal-width filled bars using its observed range."""
        var series = RectangleSeries._histogram(data, bins, False, 0.0, 1.0)
        self._insert_rectangles(series^, label^, style)

    def histogram(
        mut self,
        data: Span[Float64, ...],
        range_lo: Float64,
        range_hi: Float64,
        *,
        bins: Int = 10,
        var label: String = String(),
        style: SeriesStyle = SeriesStyle(),
    ) raises:
        """Bin finite data within an explicit inclusive range."""
        var series = RectangleSeries._histogram(data, bins, True, range_lo, range_hi)
        self._insert_rectangles(series^, label^, style)

    def set_accessible_description(mut self, var description: String):
        """Set optional author-written plain text for the exported description.

        Empty text restores the generic default. XML scalar validation occurs
        at encoding, consistently with other plot text.
        """
        self._accessible_description = description^

    def accessible_description(self) -> ref[self._accessible_description] String:
        """Borrow the author-written description; empty means unspecified."""
        return self._accessible_description

    def set_title(mut self, var title: String):
        """Set title text exactly and deterministically without raising."""
        self._title = title^
        self._title_kind = TextKind.PLAIN

    def set_title(mut self, title: Text):
        """Set plain or explicitly marked Typst title text by value."""
        self._title = title.source()
        self._title_kind = title.kind()

    def set_x_label(mut self, var label: String):
        """Set x-axis label text exactly and deterministically without raising."""
        self._x_label = label^
        self._x_label_kind = TextKind.PLAIN

    def set_x_label(mut self, label: Text):
        """Set a plain or explicitly marked Typst x-axis label."""
        self._x_label = label.source()
        self._x_label_kind = label.kind()

    def set_y_label(mut self, var label: String):
        """Set y-axis label text exactly and deterministically without raising."""
        self._y_label = label^
        self._y_label_kind = TextKind.PLAIN

    def set_y_label(mut self, label: Text):
        """Set a plain or explicitly marked Typst y-axis label."""
        self._y_label = label.source()
        self._y_label_kind = label.kind()

    def set_legend(mut self, position: LegendPosition):
        """Set deterministic legend placement without validation or raising."""
        self._legend_position = position

    def set_grid(mut self, enabled: Bool):
        """Enable or disable deterministic major gridlines without raising."""
        self._grid_enabled = enabled

    def set_config(mut self, config: FigureConfig) raises:
        """Replace physical size and export DPI after validating them."""
        config.validate()
        self._config = config

    def set_size(mut self, width: Float64, height: Float64) raises:
        """Set physical size in inches without changing export DPI."""
        self._config = self._config.with_size(width, height)

    def set_size_px(mut self, width: Int, height: Int) raises:
        """Set physical size from pixels at the current unchanged DPI."""
        self._config = self._config.with_size_px(width, height)

    def set_dpi(mut self, dpi: Float64) raises:
        """Set export DPI without changing the stored physical size."""
        self._config = self._config.with_dpi(dpi)

    def set_theme(mut self, theme: Theme) raises:
        """Replace backend-independent visual values after validation."""
        theme.validate()
        self._theme = theme

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

    def clear_x_limits(mut self):
        """Restore automatic x-domain selection deterministically."""
        self._has_x_limits = False
        self._x_limit_lo = 0.0
        self._x_limit_hi = 1.0

    def clear_y_limits(mut self):
        """Restore automatic y-domain selection deterministically."""
        self._has_y_limits = False
        self._y_limit_lo = 0.0
        self._y_limit_hi = 1.0

    def set_x_ticks(
        mut self,
        positions: Span[Float64, ...],
        labels: Span[String, _],
    ) raises:
        """Replace x ticks atomically with explicit positions and labels."""
        if len(positions) != len(labels):
            raise Error(
                "x tick position length ",
                len(positions),
                " must equal label length ",
                len(labels),
                "; pass one label per position",
            )
        var stored_positions = List[Float64](capacity=len(positions))
        var stored_labels = List[String](capacity=len(labels))
        for index in range(len(positions)):
            if not isfinite(positions[index]):
                raise Error(
                    "x tick position at index ",
                    index,
                    " must be finite; got ",
                    positions[index],
                    "; replace the invalid position",
                )
            if index > 0 and positions[index] <= positions[index - 1]:
                raise Error(
                    "x tick positions must be strictly increasing; index ",
                    index,
                    " has value ",
                    positions[index],
                    ", which is not greater than previous value ",
                    positions[index - 1],
                    "; sort positions and remove duplicates",
                )
            stored_positions.append(positions[index])
            stored_labels.append(labels[index].copy())
        self._has_x_ticks = True
        self._x_tick_positions = stored_positions^
        self._x_tick_labels = stored_labels^

    def clear_x_ticks(mut self):
        """Restore automatic x tick positions and numeric labels."""
        self._has_x_ticks = False
        self._x_tick_positions = List[Float64]()
        self._x_tick_labels = List[String]()

    def set_y_ticks(
        mut self,
        positions: Span[Float64, ...],
        labels: Span[String, _],
    ) raises:
        """Replace y ticks atomically with owned positions and labels."""
        if len(positions) != len(labels):
            raise Error(
                "y tick position length ",
                len(positions),
                " must equal label length ",
                len(labels),
                "; pass one label per position",
            )
        var stored_positions = List[Float64](capacity=len(positions))
        var stored_labels = List[String](capacity=len(labels))
        for index in range(len(positions)):
            if not isfinite(positions[index]):
                raise Error(
                    "y tick position at index ",
                    index,
                    " must be finite; got ",
                    positions[index],
                    "; replace the invalid position",
                )
            if index > 0 and positions[index] <= positions[index - 1]:
                raise Error(
                    "y tick positions must be strictly increasing; index ",
                    index,
                    " has value ",
                    positions[index],
                    ", which is not greater than previous value ",
                    positions[index - 1],
                    "; sort positions and remove duplicates",
                )
            stored_positions.append(positions[index])
            stored_labels.append(labels[index].copy())
        self._has_y_ticks = True
        self._y_tick_positions = stored_positions^
        self._y_tick_labels = stored_labels^

    def clear_y_ticks(mut self):
        """Restore automatic y tick positions and numeric labels."""
        self._has_y_ticks = False
        self._y_tick_positions = List[Float64]()
        self._y_tick_labels = List[String]()

    def title(self) -> ref[self._title] String:
        """Return the exact stored title by read reference without raising."""
        return self._title

    def title_text(self) -> Text:
        """Return the stored title source and interpretation by value."""
        return Text(_kind=self._title_kind, _source=self._title)

    def title_kind(self) -> TextKind:
        """Return the title interpretation without copying its source."""
        return self._title_kind

    def x_label(self) -> ref[self._x_label] String:
        """Return the exact stored x label by read reference without raising."""
        return self._x_label

    def x_label_text(self) -> Text:
        """Return the stored x-axis label and interpretation by value."""
        return Text(_kind=self._x_label_kind, _source=self._x_label)

    def x_label_kind(self) -> TextKind:
        """Return the x-axis label interpretation without copying its source."""
        return self._x_label_kind

    def y_label(self) -> ref[self._y_label] String:
        """Return the exact stored y label by read reference without raising."""
        return self._y_label

    def y_label_text(self) -> Text:
        """Return the stored y-axis label and interpretation by value."""
        return Text(_kind=self._y_label_kind, _source=self._y_label)

    def y_label_kind(self) -> TextKind:
        """Return the y-axis label interpretation without copying its source."""
        return self._y_label_kind

    def legend_position(self) -> LegendPosition:
        """Return deterministic legend placement without raising."""
        return self._legend_position

    def grid_enabled(self) -> Bool:
        """Return the stored major-grid flag without raising."""
        return self._grid_enabled

    def config(self) -> FigureConfig:
        """Return physical size and export DPI by value."""
        return self._config

    def theme(self) -> Theme:
        """Return backend-independent visual values by value."""
        return self._theme

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

    def has_explicit_x_ticks(self) -> Bool:
        """Return whether rendering uses caller-supplied x ticks."""
        return self._has_x_ticks

    def x_tick_count(self) -> Int:
        """Return the explicit x tick count, or zero for automatic ticks."""
        if not self._has_x_ticks:
            return 0
        return len(self._x_tick_positions)

    def x_tick_position(self, index: Int) raises -> Float64:
        """Return an explicit x tick position by checked index."""
        if not self._has_x_ticks or index < 0 or index >= len(self._x_tick_positions):
            raise Error(
                "x tick index must be within [0, ",
                len(self._x_tick_positions),
                "); got ",
                index,
            )
        return self._x_tick_positions[index]

    def x_tick_label(self, index: Int) raises -> ref[self._x_tick_labels[index]] String:
        """Return an explicit x tick label by checked index."""
        if not self._has_x_ticks or index < 0 or index >= len(self._x_tick_labels):
            raise Error(
                "x tick index must be within [0, ",
                len(self._x_tick_labels),
                "); got ",
                index,
            )
        return self._x_tick_labels[index]

    def has_explicit_y_ticks(self) -> Bool:
        """Return whether rendering uses caller-supplied y ticks."""
        return self._has_y_ticks

    def y_tick_count(self) -> Int:
        """Return the explicit y tick count, or zero for automatic ticks."""
        if not self._has_y_ticks:
            return 0
        return len(self._y_tick_positions)

    def y_tick_position(self, index: Int) raises -> Float64:
        """Return an explicit y tick position by checked index."""
        if not self._has_y_ticks or index < 0 or index >= len(self._y_tick_positions):
            raise Error(
                "y tick index must be within [0, ",
                len(self._y_tick_positions),
                "); got ",
                index,
            )
        return self._y_tick_positions[index]

    def y_tick_label(self, index: Int) raises -> ref[self._y_tick_labels[index]] String:
        """Return an explicit y tick label by checked index."""
        if not self._has_y_ticks or index < 0 or index >= len(self._y_tick_labels):
            raise Error(
                "y tick index must be within [0, ",
                len(self._y_tick_labels),
                "); got ",
                index,
            )
        return self._y_tick_labels[index]

    def _validate_render_configuration(self) raises:
        """Reject nominal fallthroughs without rescanning retained point data."""
        self._config.validate()
        self._theme.validate()
        self._x_scale.validate()
        self._y_scale.validate()
        self._legend_position.validate()
        self._title_kind.validate()
        self._x_label_kind.validate()
        self._y_label_kind.validate()
        for style in self._line_styles:
            style.validate()
        for style in self._scatter_styles:
            style.validate()
        for style in self._area_styles:
            style.validate()
        for style in self._rectangle_styles:
            style.validate()

    def validate(self) raises:
        """Validate all stored invariants in deterministic field and index order."""
        self._config.validate()
        self._theme.validate()
        self._x_scale.validate()
        self._y_scale.validate()
        self._legend_position.validate()
        self._title_kind.validate()
        self._x_label_kind.validate()
        self._y_label_kind.validate()
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
        for index in range(len(self._areas)):
            self._areas[index].validate()
        for index in range(len(self._rectangles)):
            self._rectangles[index].validate()
        for index in range(len(self._line_styles)):
            self._line_styles[index].validate()
        for index in range(len(self._scatter_styles)):
            self._scatter_styles[index].validate()
        for index in range(len(self._area_styles)):
            self._area_styles[index].validate()
        for index in range(len(self._rectangle_styles)):
            self._rectangle_styles[index].validate()
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
        if len(self._area_labels) != len(self._areas):
            raise Error(
                "figure area labels must match stored area series; got ",
                len(self._area_labels),
                " labels for ",
                len(self._areas),
                " series",
            )
        if len(self._area_styles) != len(self._areas):
            raise Error(
                "figure area styles must match stored area series; got ",
                len(self._area_styles),
                " styles for ",
                len(self._areas),
                " series",
            )
        if len(self._rectangle_labels) != len(self._rectangles):
            raise Error(
                "figure rectangle labels must match stored rectangle series; got ",
                len(self._rectangle_labels),
                " labels for ",
                len(self._rectangles),
                " series",
            )
        if len(self._rectangle_styles) != len(self._rectangles):
            raise Error(
                "figure rectangle styles must match stored rectangle series; got ",
                len(self._rectangle_styles),
                " styles for ",
                len(self._rectangles),
                " series",
            )
        if self._has_x_ticks:
            if len(self._x_tick_positions) != len(self._x_tick_labels):
                raise Error(
                    "figure x tick positions must match x tick labels; got ",
                    len(self._x_tick_positions),
                    " positions for ",
                    len(self._x_tick_labels),
                    " labels",
                )
            for index in range(len(self._x_tick_positions)):
                if not isfinite(self._x_tick_positions[index]):
                    raise Error(
                        "x tick position at index ",
                        index,
                        " must be finite; got ",
                        self._x_tick_positions[index],
                        "; replace the invalid position",
                    )
        elif len(self._x_tick_positions) != 0 or len(self._x_tick_labels) != 0:
            raise Error(
                "automatic x ticks must not retain explicit tick storage; got ",
                len(self._x_tick_positions),
                " positions and ",
                len(self._x_tick_labels),
                " labels; clear explicit tick storage",
            )
        if self._has_y_ticks:
            if len(self._y_tick_positions) != len(self._y_tick_labels):
                raise Error(
                    "figure y tick positions must match y tick labels; got ",
                    len(self._y_tick_positions),
                    " positions for ",
                    len(self._y_tick_labels),
                    " labels",
                )
            for index in range(len(self._y_tick_positions)):
                if not isfinite(self._y_tick_positions[index]):
                    raise Error(
                        "y tick position at index ",
                        index,
                        " must be finite; got ",
                        self._y_tick_positions[index],
                        "; replace the invalid position",
                    )
        elif len(self._y_tick_positions) != 0 or len(self._y_tick_labels) != 0:
            raise Error(
                "automatic y ticks must not retain explicit tick storage; got ",
                len(self._y_tick_positions),
                " positions and ",
                len(self._y_tick_labels),
                " labels; clear explicit tick storage",
            )
        if len(self._order) != (
            len(self._lines)
            + len(self._scatters)
            + len(self._areas)
            + len(self._rectangles)
        ):
            raise Error(
                "figure series order must include every stored series; got ",
                len(self._order),
                " order entries for ",
                len(self._lines)
                + len(self._scatters)
                + len(self._areas)
                + len(self._rectangles),
                " series",
            )

        var seen_lines = List[Bool](capacity=len(self._lines))
        for _ in range(len(self._lines)):
            seen_lines.append(False)
        var seen_scatters = List[Bool](capacity=len(self._scatters))
        for _ in range(len(self._scatters)):
            seen_scatters.append(False)
        var seen_areas = List[Bool](capacity=len(self._areas))
        for _ in range(len(self._areas)):
            seen_areas.append(False)
        var seen_rectangles = List[Bool](capacity=len(self._rectangles))
        for _ in range(len(self._rectangles)):
            seen_rectangles.append(False)
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
            elif entry.kind._value == _SeriesKind.AREA._value:
                if entry.index < 0 or entry.index >= len(self._areas):
                    raise Error("figure area order index is out of bounds")
                if seen_areas[entry.index]:
                    raise Error("figure series order must not contain duplicates")
                seen_areas[entry.index] = True
            elif entry.kind._value == _SeriesKind.RECTANGLE._value:
                if entry.index < 0 or entry.index >= len(self._rectangles):
                    raise Error("figure rectangle order index is out of bounds")
                if seen_rectangles[entry.index]:
                    raise Error("figure series order must not contain duplicates")
                seen_rectangles[entry.index] = True
            else:
                raise Error("figure series order contains an unknown kind")

    def is_empty(self) -> Bool:
        """Return whether no series are stored; this check never raises."""
        return (
            len(self._lines) == 0
            and len(self._scatters) == 0
            and len(self._areas) == 0
            and len(self._rectangles) == 0
        )

    def line_count(self) -> Int:
        """Return the deterministic stored line count without raising."""
        return len(self._lines)

    def scatter_count(self) -> Int:
        """Return the deterministic stored scatter count without raising."""
        return len(self._scatters)

    def area_count(self) -> Int:
        """Return the deterministic stored area count without raising."""
        return len(self._areas)

    def rectangle_count(self) -> Int:
        """Return the deterministic stored rectangle-series count."""
        return len(self._rectangles)

    def bounds(self) raises -> DataBounds:
        """Return combined bounds for every nonempty stored series.

        Empty series do not contribute an extent. A figure with no series and a
        figure whose series are all empty are rejected with distinct guidance.
        Bounds are combined in stable line-then-scatter-then-area-then-rectangle
        storage order.
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
        for index in range(len(self._areas)):
            if self._areas[index].is_empty():
                continue
            var current = self._areas[index].bounds()
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
        for index in range(len(self._rectangles)):
            if self._rectangles[index].is_empty():
                continue
            var current = self._rectangles[index].bounds()
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
            var series_count = (
                len(self._lines)
                + len(self._scatters)
                + len(self._areas)
                + len(self._rectangles)
            )
            if series_count == 0:
                raise Error(
                    "figure has no series; add a line, scatter, area, bar, or "
                    "histogram before rendering"
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

    def area(self, index: Int) raises -> ref[self._areas[index]] AreaSeries:
        """Return a stable area reference by checked storage index."""
        if index < 0 or index >= len(self._areas):
            raise Error(
                "figure area index must be within [0, ",
                len(self._areas),
                "); got ",
                index,
            )
        return self._areas[index]

    def rectangles(
        self, index: Int
    ) raises -> ref[self._rectangles[index]] RectangleSeries:
        """Return a stable rectangle-series reference by checked index."""
        if index < 0 or index >= len(self._rectangles):
            raise Error(
                "figure rectangle index must be within [0, ",
                len(self._rectangles),
                "); got ",
                index,
            )
        return self._rectangles[index]

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

    def area_label(self, index: Int) raises -> ref[self._area_labels[index]] String:
        """Return the exact area label by checked storage index."""
        if index < 0 or index >= len(self._area_labels):
            raise Error(
                "figure area-label index must be within [0, ",
                len(self._area_labels),
                "); got ",
                index,
            )
        return self._area_labels[index]

    def rectangle_label(
        self, index: Int
    ) raises -> ref[self._rectangle_labels[index]] String:
        """Return the exact rectangle-series label by checked index."""
        if index < 0 or index >= len(self._rectangle_labels):
            raise Error(
                "figure rectangle-label index must be within [0, ",
                len(self._rectangle_labels),
                "); got ",
                index,
            )
        return self._rectangle_labels[index]

    def _series_count(self) -> Int:
        return len(self._order)

    def _series_is_line(self, index: Int) -> Bool:
        return self._order[index].kind._value == _SeriesKind.LINE._value

    def _series_is_area(self, index: Int) -> Bool:
        return self._order[index].kind._value == _SeriesKind.AREA._value

    def _series_is_rectangle(self, index: Int) -> Bool:
        return self._order[index].kind._value == _SeriesKind.RECTANGLE._value

    def _series_index(self, index: Int) -> Int:
        return self._order[index].index

    def _series_style(self, index: Int) -> SeriesStyle:
        ref entry = self._order[index]
        if entry.kind._value == _SeriesKind.LINE._value:
            return self._line_styles[entry.index]
        if entry.kind._value == _SeriesKind.SCATTER._value:
            return self._scatter_styles[entry.index]
        if entry.kind._value == _SeriesKind.AREA._value:
            return self._area_styles[entry.index]
        return self._rectangle_styles[entry.index]

    def _series_label(self, index: Int) -> String:
        ref entry = self._order[index]
        if entry.kind._value == _SeriesKind.LINE._value:
            return self._line_labels[entry.index].copy()
        if entry.kind._value == _SeriesKind.SCATTER._value:
            return self._scatter_labels[entry.index].copy()
        if entry.kind._value == _SeriesKind.AREA._value:
            return self._area_labels[entry.index].copy()
        return self._rectangle_labels[entry.index].copy()

    def render_svg(
        self,
        width: Float64,
        height: Float64,
        margins: Margins,
    ) raises -> String:
        """Render this figure in memory with explicit canvas geometry."""
        from .svg import render_svg

        return render_svg(self, width, height, margins)

    def render_svg(
        self,
        width: Float64,
        height: Float64,
    ) raises -> String:
        """Render legacy reference-pixel geometry with adaptive margins."""
        from .svg import render_svg

        return render_svg(self, width, height)

    def render_svg(self) raises -> String:
        """Render stored physical size with DPI-independent logical geometry."""
        from .svg import render_svg

        return render_svg(self)

    def render_svg(self, options: TypstOptions) raises -> String:
        """Render stored geometry with options for marked Typst text."""
        from .svg import render_svg

        return render_svg(self, options)

    def save_svg(
        self,
        path: StringSlice,
        width: Float64,
        height: Float64,
        margins: Margins,
    ) raises:
        """Render with explicit geometry and replace ``path`` with its SVG."""
        from .svg import render_svg, write_svg

        var svg = render_svg(self, width, height, margins)
        write_svg(path, svg)

    def save_svg(
        self,
        path: StringSlice,
        width: Float64,
        height: Float64,
    ) raises:
        """Render at the requested size and save it deterministically.

        Missing parent directories are created. Rendering and I/O errors
        propagate to the caller.
        """
        from .svg import render_svg, write_svg

        var svg = render_svg(self, width, height)
        write_svg(path, svg)

    def save_svg(self, path: StringSlice) raises:
        """Render stored physical geometry and save it deterministically."""
        from .svg import render_svg, write_svg

        var svg = render_svg(self)
        write_svg(path, svg)

    def save_svg(self, path: StringSlice, options: TypstOptions) raises:
        """Render optional Typst text and replace ``path`` with the SVG."""
        from .svg import render_svg, write_svg

        var svg = render_svg(self, options)
        write_svg(path, svg)
