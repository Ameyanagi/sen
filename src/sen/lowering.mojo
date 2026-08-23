"""Backend-neutral lowering from Figure semantics to device-space commands."""

from std.collections import List
from std.math import floor, isfinite, log10

from .layout import Margins, plot_area
from .render_plan import CommandKind, DrawCommand, PlanPoint, RenderPlan
from .scale import (
    LinearScale,
    LogScale,
    StickyEdges,
    linear_ticks,
    log_ticks,
    view_bounds,
)
from .series import AxisKind, DataBounds, Figure, LegendPosition
from .style import LineStyle, MarkerStyle, _palette_color


def _empty_points() -> List[PlanPoint]:
    return List[PlanPoint]()


def _shape_command(
    kind: CommandKind,
    x1: Float64,
    y1: Float64,
    x2: Float64,
    y2: Float64,
) raises -> DrawCommand:
    return DrawCommand._from_validated(
        kind,
        x1,
        y1,
        x2,
        y2,
        _empty_points(),
        String(),
        String(),
        -1,
        -1,
        0.0,
        LineStyle.SOLID,
        MarkerStyle.NONE,
    )


def _text_command(
    kind: CommandKind, x: Float64, y: Float64, var text: String
) raises -> DrawCommand:
    return DrawCommand._from_validated(
        kind,
        x,
        y,
        0.0,
        0.0,
        _empty_points(),
        text^,
        String(),
        -1,
        -1,
        0.0,
        LineStyle.SOLID,
        MarkerStyle.NONE,
    )


def _polyline_command(
    var points: List[PlanPoint],
    color: StringSlice,
    series_index: Int,
    line_width: Float64,
    line_style: LineStyle,
) raises -> DrawCommand:
    return DrawCommand._from_validated(
        CommandKind.SERIES,
        0.0,
        0.0,
        0.0,
        0.0,
        points^,
        String(),
        String(color),
        -1,
        series_index,
        line_width,
        line_style,
        MarkerStyle.NONE,
    )


def _area_command(
    var points: List[PlanPoint],
    color: StringSlice,
    series_index: Int,
    line_width: Float64,
    line_style: LineStyle,
) raises -> DrawCommand:
    return DrawCommand._from_validated(
        CommandKind.AREA,
        0.0,
        0.0,
        0.0,
        0.0,
        points^,
        String(),
        String(color),
        -1,
        series_index,
        line_width,
        line_style,
        MarkerStyle.NONE,
    )


def _marker_command(
    kind: CommandKind,
    x: Float64,
    y: Float64,
    color: StringSlice,
    palette_slot: Int,
    series_index: Int,
    marker_style: MarkerStyle,
) raises -> DrawCommand:
    return DrawCommand._from_validated(
        kind,
        x,
        y,
        0.0,
        0.0,
        _empty_points(),
        String(),
        String(color),
        palette_slot,
        series_index,
        0.0,
        LineStyle.SOLID,
        marker_style,
    )


def _styled_line_command(
    kind: CommandKind,
    x1: Float64,
    y1: Float64,
    x2: Float64,
    y2: Float64,
    color: StringSlice,
    line_width: Float64,
    line_style: LineStyle,
) raises -> DrawCommand:
    return DrawCommand._from_validated(
        kind,
        x1,
        y1,
        x2,
        y2,
        _empty_points(),
        String(),
        String(color),
        -1,
        -1,
        line_width,
        line_style,
        MarkerStyle.NONE,
    )


def _filled_rectangle_command(
    kind: CommandKind,
    x: Float64,
    y: Float64,
    width: Float64,
    height: Float64,
    color: StringSlice,
    series_index: Int,
) raises -> DrawCommand:
    return DrawCommand._from_validated(
        kind,
        x,
        y,
        width,
        height,
        _empty_points(),
        String(),
        String(color),
        -1,
        series_index,
        0.0,
        LineStyle.SOLID,
        MarkerStyle.NONE,
    )


def _finite_extent(
    first: Float64, second: Float64, axis_name: StringSlice
) raises -> Float64:
    """Return a nonnegative rectangle extent or reject overflow explicitly."""
    var extent = abs(second - first)
    if not isfinite(extent):
        if axis_name == "x":
            raise Error("rectangle x extent is not representable; tighten the x limits")
        raise Error("rectangle y extent is not representable; tighten the y limits")
    return extent


def _area_legend_command(
    x: Float64,
    y: Float64,
    width: Float64,
    height: Float64,
    color: StringSlice,
    line_width: Float64,
    line_style: LineStyle,
) raises -> DrawCommand:
    """Preserve the fill and outline semantics of an area-series legend glyph."""
    return DrawCommand._from_validated(
        CommandKind.LEGEND_AREA,
        x,
        y,
        width,
        height,
        _empty_points(),
        String(),
        String(color),
        -1,
        -1,
        line_width,
        line_style,
        MarkerStyle.NONE,
    )


def _padded_domain(
    lo: Float64, hi: Float64, axis_name: StringSlice
) raises -> Tuple[Float64, Float64]:
    """Pad a constant domain by max(0.5, five percent of its magnitude)."""
    if lo != hi:
        return (lo, hi)
    var padding = max(0.5, abs(lo) * 0.05)
    var padded_lo = lo - padding
    var padded_hi = hi + padding
    if not isfinite(padded_lo) or not isfinite(padded_hi) or padded_lo == padded_hi:
        raise Error(
            "constant ",
            axis_name,
            " domain cannot be padded safely; got lo=",
            _diagnostic_value(lo),
            ", hi=",
            _diagnostic_value(hi),
        )
    return (padded_lo, padded_hi)


def _decimal_factor(precision: Int) raises -> Int:
    if precision < 0 or precision > 9:
        raise Error("decimal precision must be between zero and nine")
    var factor = 1
    for _ in range(precision):
        factor *= 10
    return factor


def _format_decimal(value: Float64, precision: Int) raises -> String:
    """Format a finite decimal with half-away rounding and no exponent.

    ``precision`` is the maximum number of fractional digits. Trailing zeros and
    a trailing decimal point are removed, and any rounded negative zero becomes
    ``0``. Values whose fixed representation would exceed the supported integer
    conversion range are rejected.
    """
    if not isfinite(value):
        raise Error("decimal values must be finite")
    var factor = _decimal_factor(precision)
    var magnitude = abs(value)
    if magnitude > 9.0e18 / Float64(factor):
        raise Error("fixed-decimal value exceeds the supported magnitude")
    var rounded = Int(floor(magnitude * Float64(factor) + 0.5))
    if rounded == 0:
        return String("0")

    var whole = rounded // factor
    var result = String()
    if value < 0.0:
        result += "-"
    result += String(whole)
    if precision == 0:
        return result^

    var remainder = rounded % factor
    if remainder == 0:
        return result^
    var fractional = String(remainder)
    while fractional.byte_length() < precision:
        fractional = String("0") + fractional
    while fractional.endswith("0"):
        var shortened = String(fractional[byte = : fractional.byte_length() - 1])
        fractional = shortened^
    result += "."
    result += fractional
    return result^


def _scientific_label(value: Float64) raises -> String:
    if value == 0.0:
        return String("0")
    var exponent = 0
    var mantissa = value
    while abs(mantissa) >= 10.0:
        mantissa /= 10.0
        exponent += 1
    while abs(mantissa) < 1.0:
        mantissa *= 10.0
        exponent -= 1
    return _format_decimal(mantissa, 3) + "e" + String(exponent)


def _tick_label(value: Float64, step: Float64) raises -> String:
    """Format a tick using step-derived fixed decimals or normalized exponent form."""
    var magnitude = abs(step)
    if magnitude < 0.001 or magnitude >= 1.0e12 or abs(value) >= 1.0e12:
        return _scientific_label(value)
    var decimals = 0
    while magnitude < 1.0 and decimals < 9:
        magnitude *= 10.0
        decimals += 1
    return _format_decimal(value, decimals)


def _diagnostic_value(value: Float64) raises -> String:
    """Format diagnostic data through the existing decimal/scientific rules."""
    var magnitude = abs(value)
    if magnitude >= 1.0e9 or (magnitude > 0.0 and magnitude < 1.0e-9):
        return _scientific_label(value)
    return _format_decimal(value, 9)


def _codepoint_count(text: StringSlice) -> Int:
    var count = 0
    for _ in text.codepoint_slices():
        count += 1
    return count


def _tick_step(ticks: List[Float64], domain_span: Float64) -> Float64:
    if len(ticks) >= 2:
        return abs(ticks[1] - ticks[0])
    return abs(domain_span)


def _log_padded_domain(
    lo: Float64, hi: Float64, axis_name: StringSlice
) raises -> Tuple[Float64, Float64]:
    """Pad a positive log domain by five percent in exponent space.

    A constant domain receives exactly one decade on either side. Domains whose
    requested padding cannot be represented as finite positive ``Float64``
    endpoints are rejected with deterministic axis context.
    """
    var padded_lo = lo / 10.0
    var padded_hi = hi * 10.0
    if lo != hi:
        var lo_exponent = log10(lo)
        var hi_exponent = log10(hi)
        var padding = 0.05 * (hi_exponent - lo_exponent)
        padded_lo = pow(10.0, lo_exponent - padding)
        padded_hi = pow(10.0, hi_exponent + padding)
    if (
        not isfinite(padded_lo)
        or not isfinite(padded_hi)
        or padded_lo <= 0.0
        or padded_hi <= padded_lo
    ):
        raise Error(
            "log-scale ",
            axis_name,
            " domain cannot be padded safely; got lo=",
            _diagnostic_value(lo),
            ", hi=",
            _diagnostic_value(hi),
        )
    return (padded_lo, padded_hi)


struct _AxisMapper:
    """A scale pair constructed once for one axis during plan lowering."""

    var _kind: AxisKind
    var _linear: LinearScale
    var _logarithmic: LogScale
    var _is_x: Bool

    def __init__(
        out self,
        domain_lo: Float64,
        domain_hi: Float64,
        range_start: Float64,
        range_end: Float64,
        kind: AxisKind,
        *,
        is_x: Bool,
    ):
        self._kind = kind
        self._is_x = is_x
        self._linear = LinearScale._from_validated(
            domain_lo, domain_hi, range_start, range_end
        )
        if kind == AxisKind.LOG10:
            self._logarithmic = LogScale._from_validated(
                domain_lo, domain_hi, range_start, range_end
            )
        else:
            # A valid inert value keeps this non-optional and off the hot path.
            self._logarithmic = LogScale._from_validated(
                1.0, 10.0, range_start, range_end
            )

    def map(self, value: Float64) raises -> Float64:
        var mapped: Float64
        if self._kind == AxisKind.LOG10:
            mapped = self._logarithmic.map(value)
        else:
            mapped = self._linear.map(value)
        if not isfinite(mapped):
            if self._is_x:
                raise Error(
                    "x coordinate mapping is not representable; tighten the x limits"
                )
            raise Error(
                "y coordinate mapping is not representable; tighten the y limits"
            )
        return mapped


def _validate_log_series(figure: Figure, axis_name: StringSlice) raises:
    """Reject the first non-positive series bound in insertion order."""
    for order_index in range(figure._series_count()):
        var series_index = figure._series_index(order_index)
        var minimum: Float64
        if figure._series_is_line(order_index):
            ref line = figure.line(series_index)
            if line.is_empty():
                continue
            var bounds = line.bounds()
            minimum = bounds.x_min() if axis_name == "x" else bounds.y_min()
        elif figure._series_is_area(order_index):
            ref area = figure.area(series_index)
            if area.is_empty():
                continue
            var bounds = area.bounds()
            minimum = bounds.x_min() if axis_name == "x" else bounds.y_min()
        elif figure._series_is_rectangle(order_index):
            ref rectangles = figure.rectangles(series_index)
            if rectangles.is_empty():
                continue
            var bounds = rectangles.bounds()
            minimum = bounds.x_min() if axis_name == "x" else bounds.y_min()
        else:
            ref scatter = figure.scatter(series_index)
            if scatter.is_empty():
                continue
            var bounds = scatter.bounds()
            minimum = bounds.x_min() if axis_name == "x" else bounds.y_min()
        if minimum <= 0.0:
            if axis_name == "x":
                raise Error(
                    "log-scale x domain requires positive values; series ",
                    order_index,
                    " has x_min = ",
                    _diagnostic_value(minimum),
                )
            raise Error(
                "log-scale y domain requires positive values; series ",
                order_index,
                " has y_min = ",
                _diagnostic_value(minimum),
            )


def build_render_plan(
    figure: Figure, width: Float64, height: Float64, margins: Margins
) raises -> RenderPlan:
    """Lower ``figure`` to a validated backend-neutral device-space plan.

    The operation performs no I/O and contains no SVG syntax. Commands are
    deterministic: background and frame; optional x/y grids; x axis ticks and
    labels; y axis ticks and labels; optional titles; series primitives in
    figure insertion order; then legend rows in that order. Each axis scale is
    constructed once and reused for its ordered scalar mappings. Invalid figure
    geometry, domains, logarithmic values, or empty input raises before a plan
    is returned.
    """
    figure._validate_render_configuration()
    var title = figure.title().copy()
    var x_label = figure.x_label().copy()
    var y_label = figure.y_label().copy()
    var extra_top = 18.0 if title.byte_length() > 0 else 0.0
    var extra_bottom = 14.0 if x_label.byte_length() > 0 else 0.0
    var extra_left = 14.0 if y_label.byte_length() > 0 else 0.0
    var effective_margins = Margins(
        margins.left() + extra_left,
        margins.right(),
        margins.top() + extra_top,
        margins.bottom() + extra_bottom,
    )
    var area = plot_area(width, height, effective_margins)
    var data_bounds = figure.bounds()
    var x_limits = figure.x_limits()
    var y_limits = figure.y_limits()
    var x_axis_kind = figure.x_scale()
    var y_axis_kind = figure.y_scale()
    if x_axis_kind == AxisKind.LOG10:
        if x_limits and x_limits.value()[0] <= 0.0:
            raise Error(
                "log-scale x domain requires positive values; explicit x limit lo = ",
                _diagnostic_value(x_limits.value()[0]),
            )
        _validate_log_series(figure, "x")
        if figure.has_explicit_x_ticks():
            for index in range(figure.x_tick_count()):
                if figure.x_tick_position(index) <= 0.0:
                    raise Error(
                        "log-scale x tick positions must be positive; tick ",
                        index,
                        " has value = ",
                        _diagnostic_value(figure.x_tick_position(index)),
                        "; replace it or use AxisKind.LINEAR",
                    )
    if y_axis_kind == AxisKind.LOG10:
        if y_limits and y_limits.value()[0] <= 0.0:
            raise Error(
                "log-scale y domain requires positive values; explicit y limit lo = ",
                _diagnostic_value(y_limits.value()[0]),
            )
        _validate_log_series(figure, "y")
        if figure.has_explicit_y_ticks():
            for index in range(figure.y_tick_count()):
                if figure.y_tick_position(index) <= 0.0:
                    raise Error(
                        "log-scale y tick positions must be positive; tick ",
                        index,
                        " has value = ",
                        _diagnostic_value(figure.y_tick_position(index)),
                        "; replace it or use AxisKind.LINEAR",
                    )
    var autoscale_x_min = data_bounds.x_min()
    var autoscale_x_max = data_bounds.x_max()
    if x_limits:
        autoscale_x_min = 0.0
        autoscale_x_max = 1.0
    var autoscale_y_min = data_bounds.y_min()
    var autoscale_y_max = data_bounds.y_max()
    if y_limits:
        autoscale_y_min = 0.0
        autoscale_y_max = 1.0
    var sticky = StickyEdges.NONE
    for index in range(figure.rectangle_count()):
        ref rectangles = figure.rectangles(index)
        if rectangles.is_empty():
            continue
        var rectangle_bounds = rectangles.bounds()
        if rectangle_bounds.y_min() == 0.0 or rectangle_bounds.y_max() == 0.0:
            sticky = StickyEdges.Y_ZERO_BASELINE
            break
    if sticky == StickyEdges.NONE:
        for index in range(figure.area_count()):
            ref filled_area = figure.area(index)
            if not filled_area.is_empty() and filled_area.baseline() == 0.0:
                sticky = StickyEdges.Y_ZERO_BASELINE
                break
    var bounds = view_bounds(
        DataBounds(
            autoscale_x_min,
            autoscale_x_max,
            autoscale_y_min,
            autoscale_y_max,
        ),
        margin=0.05,
        sticky=sticky,
    )
    var x_domain = _padded_domain(bounds.x_min(), bounds.x_max(), "x")
    var y_domain = _padded_domain(bounds.y_min(), bounds.y_max(), "y")
    if x_limits:
        x_domain = x_limits.value()
    elif x_axis_kind == AxisKind.LOG10:
        x_domain = _log_padded_domain(data_bounds.x_min(), data_bounds.x_max(), "x")
    if y_limits:
        y_domain = y_limits.value()
    elif y_axis_kind == AxisKind.LOG10:
        y_domain = _log_padded_domain(data_bounds.y_min(), data_bounds.y_max(), "y")
    # Construct each axis scale exactly once. The scalar maps below are the real
    # ordered plan path, so profiling includes the same work production uses.
    var x_mapper = _AxisMapper(
        x_domain[0],
        x_domain[1],
        area.x(),
        area.x() + area.width(),
        x_axis_kind,
        is_x=True,
    )
    var y_mapper = _AxisMapper(
        y_domain[0],
        y_domain[1],
        area.y() + area.height(),
        area.y(),
        y_axis_kind,
        is_x=False,
    )
    var x_ticks: List[Float64]
    var explicit_x_tick_labels = List[String]()
    var y_ticks: List[Float64]
    var explicit_y_tick_labels = List[String]()
    if figure.has_explicit_x_ticks():
        x_ticks = List[Float64](capacity=figure.x_tick_count())
        explicit_x_tick_labels = List[String](capacity=figure.x_tick_count())
        for index in range(figure.x_tick_count()):
            var position = figure.x_tick_position(index)
            if position < x_domain[0] or position > x_domain[1]:
                continue
            x_ticks.append(position)
            explicit_x_tick_labels.append(figure.x_tick_label(index).copy())
    elif x_axis_kind == AxisKind.LOG10:
        x_ticks = log_ticks(x_domain[0], x_domain[1])
    else:
        x_ticks = linear_ticks(x_domain[0], x_domain[1])
    if figure.has_explicit_y_ticks():
        y_ticks = List[Float64](capacity=figure.y_tick_count())
        explicit_y_tick_labels = List[String](capacity=figure.y_tick_count())
        for index in range(figure.y_tick_count()):
            var position = figure.y_tick_position(index)
            if position < y_domain[0] or position > y_domain[1]:
                continue
            y_ticks.append(position)
            explicit_y_tick_labels.append(figure.y_tick_label(index).copy())
    elif y_axis_kind == AxisKind.LOG10:
        y_ticks = log_ticks(y_domain[0], y_domain[1])
    else:
        y_ticks = linear_ticks(y_domain[0], y_domain[1])
    var x_step = _tick_step(x_ticks, x_domain[1] - x_domain[0])
    var y_step = _tick_step(y_ticks, y_domain[1] - y_domain[0])

    # Size command-heavy plans before appending any command. Series topology and
    # tick lists already expose every data-dependent command count; the legend
    # allowance deliberately assumes that every series is labeled so this sizing
    # pass does not duplicate legend text measurement. Small plans retain List's
    # default growth path because reserving them did not improve their profile.
    var command_capacity = 4 + 2 * (len(x_ticks) + len(y_ticks))
    if figure.grid_enabled():
        command_capacity += len(x_ticks) + len(y_ticks)
    if title.byte_length() > 0:
        command_capacity += 1
    if x_label.byte_length() > 0:
        command_capacity += 1
    if y_label.byte_length() > 0:
        command_capacity += 1
    for order_index in range(figure._series_count()):
        var series_index = figure._series_index(order_index)
        if figure._series_is_line(order_index):
            command_capacity += figure.line(series_index).segment_count()
        elif figure._series_is_area(order_index):
            command_capacity += figure.area(series_index).segment_count()
        elif figure._series_is_rectangle(order_index):
            command_capacity += figure.rectangles(series_index).rectangle_count()
        else:
            command_capacity += figure.scatter(series_index).point_count()
    if figure.legend_position() != LegendPosition.NONE:
        command_capacity += 1 + 2 * figure._series_count()
    var commands: List[DrawCommand]
    if command_capacity >= 64:
        commands = List[DrawCommand](capacity=command_capacity)
    else:
        commands = List[DrawCommand]()
    commands.append(_shape_command(CommandKind.BACKGROUND, 0.0, 0.0, width, height))
    commands.append(
        _shape_command(
            CommandKind.FRAME,
            area.x(),
            area.y(),
            area.width(),
            area.height(),
        )
    )
    var bottom = area.y() + area.height()
    if figure.grid_enabled():
        for tick in x_ticks:
            var x = x_mapper.map(tick)
            commands.append(_shape_command(CommandKind.GRID, x, area.y(), x, bottom))
        for tick in y_ticks:
            var y = y_mapper.map(tick)
            commands.append(
                _shape_command(
                    CommandKind.GRID,
                    area.x(),
                    y,
                    area.x() + area.width(),
                    y,
                )
            )
    commands.append(
        _shape_command(
            CommandKind.AXIS,
            area.x(),
            bottom,
            area.x() + area.width(),
            bottom,
        )
    )
    for tick_index in range(len(x_ticks)):
        var tick = x_ticks[tick_index]
        var x = x_mapper.map(tick)
        commands.append(_shape_command(CommandKind.TICK, x, bottom, x, bottom + 4.0))
        var tick_text = _tick_label(tick, x_step)
        if figure.has_explicit_x_ticks():
            tick_text = explicit_x_tick_labels[tick_index].copy()
        commands.append(
            _text_command(
                CommandKind.X_LABEL,
                x,
                bottom + 14.0,
                tick_text^,
            )
        )

    commands.append(
        _shape_command(
            CommandKind.AXIS,
            area.x(),
            area.y(),
            area.x(),
            bottom,
        )
    )
    for tick_index in range(len(y_ticks)):
        var tick = y_ticks[tick_index]
        var y = y_mapper.map(tick)
        commands.append(
            _shape_command(
                CommandKind.TICK,
                area.x() - 4.0,
                y,
                area.x(),
                y,
            )
        )
        var tick_text = _tick_label(tick, y_step)
        if figure.has_explicit_y_ticks():
            tick_text = explicit_y_tick_labels[tick_index].copy()
        commands.append(
            _text_command(
                CommandKind.Y_LABEL,
                area.x() - 6.0,
                y + 3.0,
                tick_text^,
            )
        )

    if title.byte_length() > 0:
        commands.append(
            _text_command(
                CommandKind.TITLE,
                area.x() + area.width() / 2.0,
                area.y() - 6.0,
                title^,
            )
        )
    if x_label.byte_length() > 0:
        commands.append(
            _text_command(
                CommandKind.X_TITLE,
                area.x() + area.width() / 2.0,
                bottom + 28.0,
                x_label^,
            )
        )
    if y_label.byte_length() > 0:
        commands.append(
            _text_command(
                CommandKind.Y_TITLE,
                area.x() - 14.0,
                area.y() + area.height() / 2.0,
                y_label^,
            )
        )

    var auto_color_index = 0
    var resolved_slots = List[Int](capacity=figure._series_count())
    var resolved_colors = List[String](capacity=figure._series_count())
    for order_index in range(figure._series_count()):
        var series_index = figure._series_index(order_index)
        var style = figure._series_style(order_index)
        var palette_slot = style.palette_slot()
        var color = style.color()
        if color.byte_length() > 0:
            palette_slot = -1
        elif palette_slot == -1:
            palette_slot = auto_color_index % 6
            auto_color_index += 1
            color = _palette_color(palette_slot)
        else:
            color = _palette_color(palette_slot)
        resolved_slots.append(palette_slot)
        resolved_colors.append(color.copy())
        if figure._series_is_line(order_index):
            ref line = figure.line(series_index)
            for segment_index in range(line.segment_count()):
                var segment_length = line.segment_point_count(segment_index)
                # The profile showed geometric list growth in the real line
                # plan path. Segment topology already gives the exact size.
                var points = List[PlanPoint](capacity=segment_length)
                for point_index in range(segment_length):
                    var point = line.segment_point(segment_index, point_index)
                    points.append(
                        PlanPoint._from_validated(
                            x_mapper.map(point.x()),
                            y_mapper.map(point.y()),
                        )
                    )
                commands.append(
                    _polyline_command(
                        points^,
                        color,
                        order_index,
                        style.line_width(),
                        style.line_style(),
                    )
                )
        elif figure._series_is_area(order_index):
            ref filled_area = figure.area(series_index)
            var baseline_y = y_mapper.map(filled_area.baseline())
            for segment_index in range(filled_area.segment_count()):
                var segment_length = filled_area.segment_point_count(segment_index)
                if segment_length == 0:
                    continue
                var points = List[PlanPoint](capacity=segment_length + 2)
                var first = filled_area.segment_point(segment_index, 0)
                points.append(
                    PlanPoint._from_validated(
                        x_mapper.map(first.x()),
                        baseline_y,
                    )
                )
                for point_index in range(segment_length):
                    var point = filled_area.segment_point(segment_index, point_index)
                    points.append(
                        PlanPoint._from_validated(
                            x_mapper.map(point.x()),
                            y_mapper.map(point.y()),
                        )
                    )
                var last = filled_area.segment_point(segment_index, segment_length - 1)
                points.append(
                    PlanPoint._from_validated(
                        x_mapper.map(last.x()),
                        baseline_y,
                    )
                )
                commands.append(
                    _area_command(
                        points^,
                        color,
                        order_index,
                        style.line_width(),
                        style.line_style(),
                    )
                )
        elif figure._series_is_rectangle(order_index):
            ref rectangles = figure.rectangles(series_index)
            for rectangle_index in range(rectangles.rectangle_count()):
                var rectangle = rectangles.rectangle(rectangle_index)
                var left = x_mapper.map(rectangle.left())
                var right = x_mapper.map(rectangle.right())
                var bottom_y = y_mapper.map(rectangle.bottom())
                var top_y = y_mapper.map(rectangle.top())
                commands.append(
                    _filled_rectangle_command(
                        CommandKind.RECTANGLE,
                        min(left, right),
                        min(top_y, bottom_y),
                        _finite_extent(left, right, "x"),
                        _finite_extent(top_y, bottom_y, "y"),
                        color,
                        order_index,
                    )
                )
        else:
            ref scatter = figure.scatter(series_index)
            for point_index in range(scatter.point_count()):
                var point = scatter.point(point_index)
                commands.append(
                    _marker_command(
                        CommandKind.MARKER,
                        x_mapper.map(point.x()),
                        y_mapper.map(point.y()),
                        color,
                        palette_slot,
                        order_index,
                        style.marker_style(),
                    )
                )

    var legend_position = figure.legend_position()
    if legend_position != LegendPosition.NONE:
        var labeled_count = 0
        var longest_label = 0
        for order_index in range(figure._series_count()):
            var label = figure._series_label(order_index)
            if label.byte_length() == 0:
                continue
            labeled_count += 1
            longest_label = max(longest_label, _codepoint_count(label))
        if labeled_count > 0:
            # Text measurement is intentionally replaced by a fixed five-unit
            # width per Unicode codepoint for byte-stable layout.
            var legend_width = 33.0 + 5.0 * Float64(longest_label)
            var legend_height = 10.0 + 14.0 * Float64(labeled_count)
            var legend_x = area.x() + 8.0
            var legend_y = area.y() + 8.0
            if (
                legend_position == LegendPosition.UPPER_RIGHT
                or legend_position == LegendPosition.LOWER_RIGHT
            ):
                legend_x = area.x() + area.width() - 8.0 - legend_width
            if (
                legend_position == LegendPosition.LOWER_LEFT
                or legend_position == LegendPosition.LOWER_RIGHT
            ):
                legend_y = area.y() + area.height() - 8.0 - legend_height
            commands.append(
                _shape_command(
                    CommandKind.LEGEND_BACKGROUND,
                    legend_x,
                    legend_y,
                    legend_width,
                    legend_height,
                )
            )
            var row_index = 0
            for order_index in range(figure._series_count()):
                var label = figure._series_label(order_index)
                if label.byte_length() == 0:
                    continue
                var center_y = legend_y + 12.0 + 14.0 * Float64(row_index)
                var glyph_x = legend_x + 6.0
                var style = figure._series_style(order_index)
                var palette_slot = resolved_slots[order_index]
                ref color = resolved_colors[order_index]
                if figure._series_is_line(order_index):
                    commands.append(
                        _styled_line_command(
                            CommandKind.LEGEND_LINE,
                            glyph_x,
                            center_y,
                            glyph_x + 16.0,
                            center_y,
                            color,
                            style.line_width(),
                            style.line_style(),
                        )
                    )
                elif figure._series_is_area(order_index):
                    commands.append(
                        _area_legend_command(
                            glyph_x + 2.0,
                            center_y - 4.0,
                            12.0,
                            8.0,
                            color,
                            style.line_width(),
                            style.line_style(),
                        )
                    )
                elif figure._series_is_rectangle(order_index):
                    commands.append(
                        _filled_rectangle_command(
                            CommandKind.LEGEND_RECTANGLE,
                            glyph_x + 2.0,
                            center_y - 4.0,
                            12.0,
                            8.0,
                            color,
                            -1,
                        )
                    )
                else:
                    commands.append(
                        _marker_command(
                            CommandKind.LEGEND_MARKER,
                            glyph_x + 8.0,
                            center_y,
                            color,
                            palette_slot,
                            -1,
                            style.marker_style(),
                        )
                    )
                commands.append(
                    _text_command(
                        CommandKind.LEGEND_TEXT,
                        glyph_x + 21.0,
                        center_y + 3.0,
                        label^,
                    )
                )
                row_index += 1
    return RenderPlan._from_validated(
        width,
        height,
        area.x(),
        area.y(),
        area.width(),
        area.height(),
        commands^,
    )
