"""Renderer-independent linear scales and tick location."""

from std.collections import List
from std.math import ceil, isfinite

from .series import DataBounds


struct _Validated:
    def __init__(out self):
        pass


struct StickyEdges(Copyable, Equatable, ImplicitlyCopyable):
    """Bitflags selecting zero-valued data edges that autoscaling keeps fixed."""

    var _value: Int

    comptime NONE = StickyEdges(_value=0)
    comptime X_ZERO_BASELINE = StickyEdges(_value=1)
    comptime Y_ZERO_BASELINE = StickyEdges(_value=2)
    comptime ALL_EDGES = StickyEdges(_value=3)

    def __init__(out self, *, _value: Int):
        """Construct sticky-edge bitflags for library-defined constants."""
        self._value = _value

    def __eq__(self, other: Self) -> Bool:
        """Return whether two sticky-edge values contain the same flags."""
        return self._value == other._value

    def __or__(self, other: Self) -> Self:
        """Return the union of the flags in both values."""
        return Self(_value=self._value | other._value)

    def has(self, flag: Self) -> Bool:
        """Return whether every bit in ``flag`` is present."""
        return (self._value & flag._value) == flag._value


def view_bounds(
    data: DataBounds,
    *,
    margin: Float64 = 0.05,
    sticky: StickyEdges = StickyEdges.NONE,
) raises -> DataBounds:
    """Return nondegenerate axes padded on each side by a span fraction.

    ``margin`` defaults to 5 percent and raises when it is negative or
    non-finite. An enabled zero-baseline flag prevents an original edge equal to
    exactly zero from moving outward. Degenerate axes remain unchanged so the
    renderer can apply its existing constant-domain fallback.
    """
    if not isfinite(margin) or margin < 0.0:
        raise Error("view margin must be finite and non-negative; got ", margin)

    var x_min = data.x_min()
    var x_max = data.x_max()
    if x_min != x_max:
        var x_padding = margin * (x_max - x_min)
        if not (sticky.has(StickyEdges.X_ZERO_BASELINE) and x_min == 0.0):
            x_min -= x_padding
        if not (sticky.has(StickyEdges.X_ZERO_BASELINE) and x_max == 0.0):
            x_max += x_padding

    var y_min = data.y_min()
    var y_max = data.y_max()
    if y_min != y_max:
        var y_padding = margin * (y_max - y_min)
        if not (sticky.has(StickyEdges.Y_ZERO_BASELINE) and y_min == 0.0):
            y_min -= y_padding
        if not (sticky.has(StickyEdges.Y_ZERO_BASELINE) and y_max == 0.0):
            y_max += y_padding

    return DataBounds(x_min, x_max, y_min, y_max)


struct LinearScale(Copyable, Equatable, ImplicitlyCopyable):
    """A constructor-validated affine mapping between two finite intervals.

    The domain must have distinct endpoints. Reversed domains and reversed or
    degenerate ranges are valid. Construction establishes these invariants and
    public read operations trust them thereafter. Direct mutation of
    underscore-prefixed storage is out of contract; call ``validate`` explicitly
    when a checkpoint is needed.
    """

    var _domain_start: Float64
    var _domain_end: Float64
    var _range_start: Float64
    var _range_end: Float64

    def __init__(
        out self,
        domain_start: Float64,
        domain_end: Float64,
        range_start: Float64,
        range_end: Float64,
    ) raises:
        self._domain_start = domain_start
        self._domain_end = domain_end
        self._range_start = range_start
        self._range_end = range_end
        self.validate()

    @staticmethod
    def _from_validated(
        domain_start: Float64,
        domain_end: Float64,
        range_start: Float64,
        range_end: Float64,
    ) -> Self:
        return Self(
            domain_start,
            domain_end,
            range_start,
            range_end,
            _validated=_Validated(),
        )

    def __init__(
        out self,
        domain_start: Float64,
        domain_end: Float64,
        range_start: Float64,
        range_end: Float64,
        *,
        _validated: _Validated,
    ):
        self._domain_start = domain_start
        self._domain_end = domain_end
        self._range_start = range_start
        self._range_end = range_end

    def validate(self) raises:
        """Validate the stored domain and range explicitly."""
        if (
            not isfinite(self._domain_start)
            or not isfinite(self._domain_end)
            or not isfinite(self._range_start)
            or not isfinite(self._range_end)
        ):
            raise Error("linear scale domain and range values must be finite")
        if self._domain_start == self._domain_end:
            raise Error("linear scale domain must not be degenerate")

    def domain_start(self) -> Float64:
        return self._domain_start

    def domain_end(self) -> Float64:
        return self._domain_end

    def range_start(self) -> Float64:
        return self._range_start

    def range_end(self) -> Float64:
        return self._range_end

    def map(self, value: Float64) -> Float64:
        """Map one value, preserving either domain endpoint exactly."""
        if value == self._domain_start:
            return self._range_start
        if value == self._domain_end:
            return self._range_end
        return self._range_start + (value - self._domain_start) * (
            self._range_end - self._range_start
        ) / (self._domain_end - self._domain_start)

    def map_all(self, values: Span[Float64, ...], mut output: List[Float64]) raises:
        """Map ``values`` into an exact-size caller-owned output buffer.

        Existing output elements are overwritten in place. The caller must
        provide one output element per input, so this batch fast path performs no
        allocation, buffer replacement, or hidden copy.
        """
        if len(values) != len(output):
            raise Error("linear scale output buffer length must match input length")
        for index in range(len(values)):
            output[index] = self.map(values[index])

    def invert(self, value: Float64) raises -> Float64:
        """Map one range value back to the domain.

        A degenerate range is valid for forward mapping but has no inverse and is
        rejected here.
        """
        if self._range_start == self._range_end:
            raise Error("degenerate linear scale range cannot be inverted")
        if value == self._range_start:
            return self._domain_start
        if value == self._range_end:
            return self._domain_end
        return self._domain_start + (value - self._range_start) * (
            self._domain_end - self._domain_start
        ) / (self._range_end - self._range_start)

    def __eq__(self, other: Self) -> Bool:
        return (
            self._domain_start == other._domain_start
            and self._domain_end == other._domain_end
            and self._range_start == other._range_start
            and self._range_end == other._range_end
        )


def _nearest_nice_step(raw_step: Float64) -> Float64:
    var normalized = raw_step
    var magnitude = 1.0
    while normalized >= 10.0:
        normalized /= 10.0
        magnitude *= 10.0
    while normalized < 1.0:
        normalized *= 10.0
        magnitude /= 10.0

    if normalized < 1.5:
        return magnitude
    if normalized < 3.5:
        return 2.0 * magnitude
    if normalized < 7.5:
        return 5.0 * magnitude
    return 10.0 * magnitude


def linear_ticks(
    domain_start: Float64, domain_end: Float64, target_count: Int = 5
) raises -> List[Float64]:
    """Return deterministic increasing ticks using 1-2-5 step selection.

    Reversed inputs are normalized to ``[lo, hi]``. The raw step is
    ``(hi - lo) / (target_count - 1)``. After normalizing the raw step to
    ``[1, 10)``, the closest of 1, 2, 5, or 10 by absolute distance is selected;
    midpoint ties select the larger step. The result is rescaled by the decimal
    magnitude. Starting at ``ceil(lo / step) * step``, ticks are generated as
    integer multiples of the step. A tolerance of ``step * 1e-9`` is applied at
    both domain boundaries to absorb floating-point division error. Results are
    strictly increasing and retain their normalized ascending order; an IEEE
    negative-zero tick is normalized to positive zero.
    """
    if not isfinite(domain_start) or not isfinite(domain_end):
        raise Error("linear tick domain values must be finite")
    if domain_start == domain_end:
        raise Error("linear tick domain must not be degenerate")
    if target_count < 2:
        raise Error("linear tick target count must be at least two")

    var lo = min(domain_start, domain_end)
    var hi = max(domain_start, domain_end)
    var raw_step = (hi - lo) / Float64(target_count - 1)
    if not isfinite(raw_step) or raw_step <= 0.0:
        raise Error("linear tick domain span must produce a finite positive step")
    var step = _nearest_nice_step(raw_step)
    if not isfinite(step) or step <= 0.0:
        raise Error("linear tick domain span must produce a finite positive step")

    var tolerance = step * 1.0e-9
    var tick_index = ceil(lo / step - 1.0e-9)
    var ticks = List[Float64]()
    var tick = tick_index * step
    while tick <= hi + tolerance:
        if tick >= lo - tolerance:
            if len(ticks) == 0 or tick > ticks[len(ticks) - 1]:
                # Adding positive zero normalizes an IEEE negative-zero tick.
                ticks.append(tick + 0.0)
        tick_index += 1.0
        var next_tick = tick_index * step
        if next_tick <= tick:
            break
        tick = next_tick
    return ticks^
