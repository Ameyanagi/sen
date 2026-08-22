"""Renderer-independent linear/logarithmic scales and tick location."""

from std.collections import List
from std.math import ceil, isfinite, log10
from std.sys import simd_width_of

from .series import DataBounds


struct _Validated:
    def __init__(out self):
        pass


struct StickyEdges(Copyable, Equatable, ImplicitlyCopyable):
    """Non-raising bitflags for deterministic zero-baseline autoscale behavior."""

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
    renderer can apply its existing constant-domain fallback. Arithmetic runs in
    fixed x-then-y, lower-then-upper order and returns deterministic bounds;
    unrepresentable derived bounds propagate ``DataBounds`` validation errors.
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


def _stable_affine(
    value: Float64,
    input_start: Float64,
    input_end: Float64,
    output_start: Float64,
    output_end: Float64,
) -> Float64:
    """Map one value without overflowing a representable affine fraction."""
    var input_span = input_end - input_start
    var output_span = output_end - output_start
    # Opposite-sign finite endpoints can have an unrepresentable subtraction
    # even though every in-domain interpolation fraction is representable.
    # Halving before subtraction preserves that fraction without overflow.
    var fraction: Float64
    if isfinite(input_span):
        fraction = (value - input_start) / input_span
    else:
        fraction = (value * 0.5 - input_start * 0.5) / (
            input_end * 0.5 - input_start * 0.5
        )
    if isfinite(output_span):
        return output_start + fraction * output_span

    # A convex combination avoids subtracting opposite-sign output endpoints.
    # Extrapolation may still be unrepresentable, as its mathematical result can
    # lie outside Float64; render-plan lowering rejects such a coordinate.
    return (1.0 - fraction) * output_start + fraction * output_end


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
            raise Error(
                (
                    "linear scale domain and range values must be finite; got "
                    "domain_start = "
                ),
                self._domain_start,
                ", domain_end = ",
                self._domain_end,
                ", range_start = ",
                self._range_start,
                ", range_end = ",
                self._range_end,
            )
        if self._domain_start == self._domain_end:
            raise Error(
                "linear scale domain must not be degenerate; got domain_start = ",
                self._domain_start,
                ", domain_end = ",
                self._domain_end,
            )

    def domain_start(self) -> Float64:
        """Return the validated first domain endpoint without raising."""
        return self._domain_start

    def domain_end(self) -> Float64:
        """Return the validated second domain endpoint without raising."""
        return self._domain_end

    def range_start(self) -> Float64:
        """Return the validated first range endpoint without raising."""
        return self._range_start

    def range_end(self) -> Float64:
        """Return the validated second range endpoint without raising."""
        return self._range_end

    def map(self, value: Float64) -> Float64:
        """Map one value, preserving either domain endpoint exactly."""
        if value == self._domain_start:
            return self._range_start
        if value == self._domain_end:
            return self._range_end
        return _stable_affine(
            value,
            self._domain_start,
            self._domain_end,
            self._range_start,
            self._range_end,
        )

    def map_all(self, values: Span[Float64, ...], mut output: List[Float64]) raises:
        """Map ``values`` into an exact-size caller-owned output buffer.

        Existing output elements are overwritten in place. The caller must
        provide one output element per input, so this batch fast path performs no
        allocation, buffer replacement, or hidden copy. A length mismatch raises
        before mutation. Complete native-width chunks use SIMD, and any remainder
        uses the scalar mapping with identical endpoint-preserving semantics.
        """
        if len(values) != len(output):
            raise Error(
                (
                    "linear scale output buffer length must match input length; got "
                    "len(values) = "
                ),
                len(values),
                ", len(output) = ",
                len(output),
            )

        comptime width = simd_width_of[DType.float64]()
        var vector_end = len(values) - len(values) % width
        if vector_end == 0:
            for index in range(len(values)):
                output[index] = self.map(values[index])
            return

        # Safety: length equality is established above, and vector_end is rounded
        # down to a whole SIMD width. Every unsafe load and store therefore stays
        # within both live contiguous buffers; neither pointer escapes this scope.
        var input_ptr = values.unsafe_ptr()
        var output_ptr = output.unsafe_ptr()
        var domain_start = SIMD[DType.float64, width](self._domain_start)
        var domain_end = SIMD[DType.float64, width](self._domain_end)
        var range_start = SIMD[DType.float64, width](self._range_start)
        var range_end = SIMD[DType.float64, width](self._range_end)
        var scalar_domain_span = self._domain_end - self._domain_start
        var scalar_range_span = self._range_end - self._range_start
        var domain_span = SIMD[DType.float64, width](scalar_domain_span)
        var range_span = SIMD[DType.float64, width](scalar_range_span)
        var half = SIMD[DType.float64, width](0.5)
        var one = SIMD[DType.float64, width](1.0)
        for index in range(0, vector_end, width):
            var value = input_ptr.unsafe_load[width=width](index)
            var fraction: SIMD[DType.float64, width]
            if isfinite(scalar_domain_span):
                fraction = (value - domain_start) / domain_span
            else:
                fraction = (value * half - domain_start * half) / (
                    domain_end * half - domain_start * half
                )
            var mapped: SIMD[DType.float64, width]
            if isfinite(scalar_range_span):
                mapped = range_start + fraction * range_span
            else:
                mapped = (one - fraction) * range_start + fraction * range_end

            # Apply the second scalar branch first so domain_start keeps priority
            # even if out-of-contract direct field mutation made endpoints equal.
            mapped = value.eq(domain_end).select(range_end, mapped)
            mapped = value.eq(domain_start).select(range_start, mapped)
            output_ptr.unsafe_store[width=width](index, mapped)

        for index in range(vector_end, len(values)):
            output[index] = self.map(values[index])

    def invert(self, value: Float64) raises -> Float64:
        """Map one range value back to the domain.

        A degenerate range is valid for forward mapping but has no inverse and is
        rejected here.
        """
        if self._range_start == self._range_end:
            raise Error(
                "degenerate linear scale range cannot be inverted; got range_start = ",
                self._range_start,
                ", range_end = ",
                self._range_end,
            )
        if value == self._range_start:
            return self._domain_start
        if value == self._range_end:
            return self._domain_end
        return _stable_affine(
            value,
            self._range_start,
            self._range_end,
            self._domain_start,
            self._domain_end,
        )

    def __eq__(self, other: Self) -> Bool:
        """Return exact deterministic endpoint equality without raising."""
        return (
            self._domain_start == other._domain_start
            and self._domain_end == other._domain_end
            and self._range_start == other._range_start
            and self._range_end == other._range_end
        )


struct LogScale(Copyable, Equatable, ImplicitlyCopyable):
    """A constructor-validated base-10 logarithmic interval mapping.

    Domain endpoints must be finite, positive, and distinct; range endpoints
    must be finite. Reversed domains and reversed or degenerate ranges are
    valid. Mapping is deterministic affine interpolation in base-10 logarithm
    space and preserves either domain endpoint exactly. Construction establishes
    the invariants, and public reads trust them thereafter. Direct mutation of
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
        """Validate the stored domain and range, naming an invalid value."""
        if not isfinite(self._domain_start):
            raise Error(
                "log scale domain_start must be finite; got domain_start = ",
                self._domain_start,
                ", domain_end = ",
                self._domain_end,
            )
        if not isfinite(self._domain_end):
            raise Error(
                "log scale domain_end must be finite; got domain_start = ",
                self._domain_start,
                ", domain_end = ",
                self._domain_end,
            )
        if not isfinite(self._range_start):
            raise Error(
                "log scale range_start must be finite; got range_start = ",
                self._range_start,
                ", range_end = ",
                self._range_end,
            )
        if not isfinite(self._range_end):
            raise Error(
                "log scale range_end must be finite; got range_start = ",
                self._range_start,
                ", range_end = ",
                self._range_end,
            )
        if self._domain_start <= 0.0:
            raise Error(
                "log scale domain_start must be positive; got domain_start = ",
                self._domain_start,
                ", domain_end = ",
                self._domain_end,
            )
        if self._domain_end <= 0.0:
            raise Error(
                "log scale domain_end must be positive; got domain_start = ",
                self._domain_start,
                ", domain_end = ",
                self._domain_end,
            )
        if self._domain_start == self._domain_end:
            raise Error(
                "log scale domain must not be degenerate; got domain_start = ",
                self._domain_start,
                ", domain_end = ",
                self._domain_end,
            )

    def domain_start(self) -> Float64:
        """Return the validated first domain endpoint without revalidation."""
        return self._domain_start

    def domain_end(self) -> Float64:
        """Return the validated second domain endpoint without revalidation."""
        return self._domain_end

    def range_start(self) -> Float64:
        """Return the validated first range endpoint without revalidation."""
        return self._range_start

    def range_end(self) -> Float64:
        """Return the validated second range endpoint without revalidation."""
        return self._range_end

    def map(self, value: Float64) -> Float64:
        """Map a trusted positive value, preserving domain endpoints exactly."""
        if value == self._domain_start:
            return self._range_start
        if value == self._domain_end:
            return self._range_end
        return self._range_start + (log10(value) - log10(self._domain_start)) * (
            self._range_end - self._range_start
        ) / (log10(self._domain_end) - log10(self._domain_start))

    def invert(self, value: Float64) raises -> Float64:
        """Invert one range value; reject a degenerate range deterministically."""
        if self._range_start == self._range_end:
            raise Error(
                "degenerate log scale range cannot be inverted; got range_start = ",
                self._range_start,
                ", range_end = ",
                self._range_end,
            )
        if value == self._range_start:
            return self._domain_start
        if value == self._range_end:
            return self._domain_end
        var exponent = log10(self._domain_start) + (value - self._range_start) * (
            log10(self._domain_end) - log10(self._domain_start)
        ) / (self._range_end - self._range_start)
        return pow(10.0, exponent)

    def map_all(self, values: Span[Float64, ...], mut output: List[Float64]) raises:
        """Map into an exact-size caller-owned buffer without allocation.

        The method rejects a length mismatch before mutating ``output``. Values
        are trusted positive inputs under the same contract as ``map``; output
        order and scalar evaluation order are deterministic.
        """
        if len(values) != len(output):
            raise Error(
                (
                    "log scale output buffer length must match input length; got "
                    "len(values) = "
                ),
                len(values),
                ", len(output) = ",
                len(output),
            )
        for index in range(len(values)):
            output[index] = self.map(values[index])

    def __eq__(self, other: Self) -> Bool:
        """Return exact endpoint equality for two validated log scales."""
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

    Non-finite or degenerate endpoints, a target below two, and any domain span
    that cannot produce a finite positive step raise before ticks are returned.
    """
    if not isfinite(domain_start) or not isfinite(domain_end):
        raise Error(
            "linear tick domain values must be finite; got domain_start = ",
            domain_start,
            ", domain_end = ",
            domain_end,
        )
    if domain_start == domain_end:
        raise Error(
            "linear tick domain must not be degenerate; got domain_start = ",
            domain_start,
            ", domain_end = ",
            domain_end,
        )
    if target_count < 2:
        raise Error("linear tick target count must be at least two; got ", target_count)

    var lo = min(domain_start, domain_end)
    var hi = max(domain_start, domain_end)
    var raw_step = (hi - lo) / Float64(target_count - 1)
    if not isfinite(raw_step) or raw_step <= 0.0:
        raise Error(
            (
                "linear tick domain span must produce a finite positive step; got "
                "domain_start = "
            ),
            domain_start,
            ", domain_end = ",
            domain_end,
            ", target_count = ",
            target_count,
            ", raw_step = ",
            raw_step,
        )
    var step = _nearest_nice_step(raw_step)
    if not isfinite(step) or step <= 0.0:
        raise Error(
            (
                "linear tick domain span must produce a finite positive step; got "
                "domain_start = "
            ),
            domain_start,
            ", domain_end = ",
            domain_end,
            ", target_count = ",
            target_count,
            ", step = ",
            step,
        )

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


def log_ticks(domain_start: Float64, domain_end: Float64) raises -> List[Float64]:
    """Return deterministic increasing base-10 ticks inside a positive domain.

    Inputs must be finite, positive, and distinct; reversed endpoints are
    normalized. Powers of ten are generated from ``1.0`` solely by cumulative
    multiplication or division by the literal ``10.0``. If zero or one decade
    lies inside the normalized domain, the raw domain is subdivided by
    ``linear_ticks`` and its deterministic 1-2-5 machinery instead.
    """
    if not isfinite(domain_start):
        raise Error(
            "log tick domain_start must be finite; got domain_start = ",
            domain_start,
            ", domain_end = ",
            domain_end,
        )
    if not isfinite(domain_end):
        raise Error(
            "log tick domain_end must be finite; got domain_start = ",
            domain_start,
            ", domain_end = ",
            domain_end,
        )
    if domain_start <= 0.0:
        raise Error(
            "log tick domain_start must be positive; got domain_start = ",
            domain_start,
            ", domain_end = ",
            domain_end,
        )
    if domain_end <= 0.0:
        raise Error(
            "log tick domain_end must be positive; got domain_start = ",
            domain_start,
            ", domain_end = ",
            domain_end,
        )
    if domain_start == domain_end:
        raise Error(
            "log tick domain must not be degenerate; got domain_start = ",
            domain_start,
            ", domain_end = ",
            domain_end,
        )

    var lo = min(domain_start, domain_end)
    var hi = max(domain_start, domain_end)
    var decade = 1.0
    if lo >= 1.0:
        while decade <= lo / 10.0:
            decade *= 10.0
        if decade < lo:
            decade *= 10.0
    else:
        while decade > lo:
            var next_decade = decade / 10.0
            if next_decade == 0.0:
                break
            decade = next_decade
        if decade < lo:
            decade *= 10.0

    var ticks = List[Float64]()
    while isfinite(decade) and decade <= hi:
        if decade >= lo:
            ticks.append(decade)
        if decade > hi / 10.0:
            break
        var next_decade = decade * 10.0
        if next_decade <= decade:
            break
        decade = next_decade
    if len(ticks) <= 1:
        return linear_ticks(lo, hi)
    return ticks^
