"""Deterministic SVG rendering for scientific figures."""

from std.collections import List
from std.math import floor, isfinite, log10
from std.os import makedirs

from .layout import Margins, plot_area
from .scale import LinearScale, LogScale, linear_ticks, log_ticks, view_bounds
from .series import AxisKind, DataBounds, Figure, LegendPosition
from .style import LineStyle, MarkerStyle, _palette_color


struct _CommandKind(Copyable, ImplicitlyCopyable):
    var _value: Int

    comptime BACKGROUND = _CommandKind(_value=0)
    comptime FRAME = _CommandKind(_value=1)
    comptime AXIS = _CommandKind(_value=2)
    comptime TICK = _CommandKind(_value=3)
    comptime X_LABEL = _CommandKind(_value=4)
    comptime Y_LABEL = _CommandKind(_value=5)
    comptime SERIES = _CommandKind(_value=6)
    comptime TITLE = _CommandKind(_value=7)
    comptime X_TITLE = _CommandKind(_value=8)
    comptime Y_TITLE = _CommandKind(_value=9)
    comptime MARKER = _CommandKind(_value=10)
    comptime GRID = _CommandKind(_value=11)
    comptime LEGEND_BACKGROUND = _CommandKind(_value=12)
    comptime LEGEND_LINE = _CommandKind(_value=13)
    comptime LEGEND_MARKER = _CommandKind(_value=14)
    comptime LEGEND_TEXT = _CommandKind(_value=15)

    def __init__(out self, *, _value: Int):
        self._value = _value


struct _PlanPoint(Copyable, ImplicitlyCopyable):
    var x: Float64
    var y: Float64

    def __init__(out self, x: Float64, y: Float64):
        self.x = x
        self.y = y


struct _DrawCommand:
    var kind: _CommandKind
    var x1: Float64
    var y1: Float64
    var x2: Float64
    var y2: Float64
    var points: List[_PlanPoint]
    var text: String
    var color: String
    var series_index: Int
    var line_width: Float64
    var line_style: LineStyle
    var marker_style: MarkerStyle

    def __init__(
        out self,
        kind: _CommandKind,
        x1: Float64,
        y1: Float64,
        x2: Float64,
        y2: Float64,
        var points: List[_PlanPoint],
        var text: String,
        var color: String,
        series_index: Int,
        line_width: Float64,
        line_style: LineStyle,
        marker_style: MarkerStyle,
    ):
        self.kind = kind
        self.x1 = x1
        self.y1 = y1
        self.x2 = x2
        self.y2 = y2
        self.points = points^
        self.text = text^
        self.color = color^
        self.series_index = series_index
        self.line_width = line_width
        self.line_style = line_style
        self.marker_style = marker_style


struct _RenderPlan:
    var width: Float64
    var height: Float64
    var plot_x: Float64
    var plot_y: Float64
    var plot_width: Float64
    var plot_height: Float64
    var commands: List[_DrawCommand]

    def __init__(
        out self,
        width: Float64,
        height: Float64,
        plot_x: Float64,
        plot_y: Float64,
        plot_width: Float64,
        plot_height: Float64,
        var commands: List[_DrawCommand],
    ):
        self.width = width
        self.height = height
        self.plot_x = plot_x
        self.plot_y = plot_y
        self.plot_width = plot_width
        self.plot_height = plot_height
        self.commands = commands^


def _empty_points() -> List[_PlanPoint]:
    return List[_PlanPoint]()


def _shape_command(
    kind: _CommandKind,
    x1: Float64,
    y1: Float64,
    x2: Float64,
    y2: Float64,
) -> _DrawCommand:
    return _DrawCommand(
        kind,
        x1,
        y1,
        x2,
        y2,
        _empty_points(),
        String(),
        String(),
        -1,
        0.0,
        LineStyle.SOLID,
        MarkerStyle.NONE,
    )


def _text_command(
    kind: _CommandKind, x: Float64, y: Float64, var text: String
) -> _DrawCommand:
    return _DrawCommand(
        kind,
        x,
        y,
        0.0,
        0.0,
        _empty_points(),
        text^,
        String(),
        -1,
        0.0,
        LineStyle.SOLID,
        MarkerStyle.NONE,
    )


def _polyline_command(
    var points: List[_PlanPoint],
    color: StringSlice,
    series_index: Int,
    line_width: Float64,
    line_style: LineStyle,
) -> _DrawCommand:
    return _DrawCommand(
        _CommandKind.SERIES,
        0.0,
        0.0,
        0.0,
        0.0,
        points^,
        String(),
        String(color),
        series_index,
        line_width,
        line_style,
        MarkerStyle.NONE,
    )


def _marker_command(
    kind: _CommandKind,
    x: Float64,
    y: Float64,
    color: StringSlice,
    series_index: Int,
    marker_style: MarkerStyle,
) -> _DrawCommand:
    return _DrawCommand(
        kind,
        x,
        y,
        0.0,
        0.0,
        _empty_points(),
        String(),
        String(color),
        series_index,
        0.0,
        LineStyle.SOLID,
        marker_style,
    )


def _styled_line_command(
    kind: _CommandKind,
    x1: Float64,
    y1: Float64,
    x2: Float64,
    y2: Float64,
    color: StringSlice,
    line_width: Float64,
    line_style: LineStyle,
) -> _DrawCommand:
    return _DrawCommand(
        kind,
        x1,
        y1,
        x2,
        y2,
        _empty_points(),
        String(),
        String(color),
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
        raise Error(
            "SVG decimal precision must be between zero and nine; got ", precision
        )
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
        raise Error("SVG numbers must be finite; got ", value)
    var factor = _decimal_factor(precision)
    var magnitude = abs(value)
    if magnitude > 9.0e18 / Float64(factor):
        raise Error(
            "SVG fixed-decimal value exceeds the supported magnitude; got ", value
        )
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


def _format_svg_number(value: Float64) raises -> String:
    """Format SVG geometry with at most three fractional decimal places."""
    return _format_decimal(value, 3)


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


def _escape_xml(text: StringSlice) -> String:
    """Escape all five XML predefined entities while preserving Unicode."""
    var escaped = String()
    for codepoint in text.codepoint_slices():
        if codepoint == "&":
            escaped += "&amp;"
        elif codepoint == "<":
            escaped += "&lt;"
        elif codepoint == ">":
            escaped += "&gt;"
        elif codepoint == '"':
            escaped += "&quot;"
        elif codepoint == "'":
            escaped += "&apos;"
        else:
            escaped += codepoint
    return escaped^


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


def _map_axis(
    value: Float64,
    domain_lo: Float64,
    domain_hi: Float64,
    range_start: Float64,
    range_end: Float64,
    kind: AxisKind,
) -> Float64:
    if kind == AxisKind.LOG10:
        return LogScale._from_validated(
            domain_lo, domain_hi, range_start, range_end
        ).map(value)
    return LinearScale._from_validated(
        domain_lo, domain_hi, range_start, range_end
    ).map(value)


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


def _lower_figure(
    figure: Figure, width: Float64, height: Float64, margins: Margins
) raises -> _RenderPlan:
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
    if y_axis_kind == AxisKind.LOG10:
        if y_limits and y_limits.value()[0] <= 0.0:
            raise Error(
                "log-scale y domain requires positive values; explicit y limit lo = ",
                _diagnostic_value(y_limits.value()[0]),
            )
        _validate_log_series(figure, "y")
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
    var bounds = view_bounds(
        DataBounds(
            autoscale_x_min,
            autoscale_x_max,
            autoscale_y_min,
            autoscale_y_max,
        ),
        margin=0.05,
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
    var x_ticks: List[Float64]
    var y_ticks: List[Float64]
    if x_axis_kind == AxisKind.LOG10:
        x_ticks = log_ticks(x_domain[0], x_domain[1])
    else:
        x_ticks = linear_ticks(x_domain[0], x_domain[1])
    if y_axis_kind == AxisKind.LOG10:
        y_ticks = log_ticks(y_domain[0], y_domain[1])
    else:
        y_ticks = linear_ticks(y_domain[0], y_domain[1])
    var x_step = _tick_step(x_ticks, x_domain[1] - x_domain[0])
    var y_step = _tick_step(y_ticks, y_domain[1] - y_domain[0])

    var commands = List[_DrawCommand]()
    commands.append(_shape_command(_CommandKind.BACKGROUND, 0.0, 0.0, width, height))
    commands.append(
        _shape_command(
            _CommandKind.FRAME,
            area.x(),
            area.y(),
            area.width(),
            area.height(),
        )
    )
    var bottom = area.y() + area.height()
    if figure.grid_enabled():
        for tick in x_ticks:
            var x = _map_axis(
                tick,
                x_domain[0],
                x_domain[1],
                area.x(),
                area.x() + area.width(),
                x_axis_kind,
            )
            commands.append(_shape_command(_CommandKind.GRID, x, area.y(), x, bottom))
        for tick in y_ticks:
            var y = _map_axis(
                tick,
                y_domain[0],
                y_domain[1],
                area.y() + area.height(),
                area.y(),
                y_axis_kind,
            )
            commands.append(
                _shape_command(
                    _CommandKind.GRID,
                    area.x(),
                    y,
                    area.x() + area.width(),
                    y,
                )
            )
    commands.append(
        _shape_command(
            _CommandKind.AXIS,
            area.x(),
            bottom,
            area.x() + area.width(),
            bottom,
        )
    )
    for tick in x_ticks:
        var x = _map_axis(
            tick,
            x_domain[0],
            x_domain[1],
            area.x(),
            area.x() + area.width(),
            x_axis_kind,
        )
        commands.append(_shape_command(_CommandKind.TICK, x, bottom, x, bottom + 4.0))
        commands.append(
            _text_command(
                _CommandKind.X_LABEL,
                x,
                bottom + 14.0,
                _tick_label(tick, x_step),
            )
        )

    commands.append(
        _shape_command(
            _CommandKind.AXIS,
            area.x(),
            area.y(),
            area.x(),
            bottom,
        )
    )
    for tick in y_ticks:
        var y = _map_axis(
            tick,
            y_domain[0],
            y_domain[1],
            area.y() + area.height(),
            area.y(),
            y_axis_kind,
        )
        commands.append(
            _shape_command(
                _CommandKind.TICK,
                area.x() - 4.0,
                y,
                area.x(),
                y,
            )
        )
        commands.append(
            _text_command(
                _CommandKind.Y_LABEL,
                area.x() - 6.0,
                y + 3.0,
                _tick_label(tick, y_step),
            )
        )

    if title.byte_length() > 0:
        commands.append(
            _text_command(
                _CommandKind.TITLE,
                area.x() + area.width() / 2.0,
                area.y() - 6.0,
                title^,
            )
        )
    if x_label.byte_length() > 0:
        commands.append(
            _text_command(
                _CommandKind.X_TITLE,
                area.x() + area.width() / 2.0,
                bottom + 28.0,
                x_label^,
            )
        )
    if y_label.byte_length() > 0:
        commands.append(
            _text_command(
                _CommandKind.Y_TITLE,
                area.x() - 14.0,
                area.y() + area.height() / 2.0,
                y_label^,
            )
        )

    var auto_color_index = 0
    var resolved_colors = List[String](capacity=figure._series_count())
    for order_index in range(figure._series_count()):
        var series_index = figure._series_index(order_index)
        var style = figure._series_style(order_index)
        var color = style.color()
        if color.byte_length() == 0:
            var palette_slot = style.palette_slot()
            if palette_slot == -1:
                palette_slot = auto_color_index % 6
                auto_color_index += 1
            color = _palette_color(palette_slot)
        resolved_colors.append(color.copy())
        if figure._series_is_line(order_index):
            ref line = figure.line(series_index)
            for segment_index in range(line.segment_count()):
                var points = List[_PlanPoint]()
                for point_index in range(line.segment_point_count(segment_index)):
                    var point = line.segment_point(segment_index, point_index)
                    points.append(
                        _PlanPoint(
                            _map_axis(
                                point.x(),
                                x_domain[0],
                                x_domain[1],
                                area.x(),
                                area.x() + area.width(),
                                x_axis_kind,
                            ),
                            _map_axis(
                                point.y(),
                                y_domain[0],
                                y_domain[1],
                                area.y() + area.height(),
                                area.y(),
                                y_axis_kind,
                            ),
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
        else:
            ref scatter = figure.scatter(series_index)
            for point_index in range(scatter.point_count()):
                var point = scatter.point(point_index)
                commands.append(
                    _marker_command(
                        _CommandKind.MARKER,
                        _map_axis(
                            point.x(),
                            x_domain[0],
                            x_domain[1],
                            area.x(),
                            area.x() + area.width(),
                            x_axis_kind,
                        ),
                        _map_axis(
                            point.y(),
                            y_domain[0],
                            y_domain[1],
                            area.y() + area.height(),
                            area.y(),
                            y_axis_kind,
                        ),
                        color,
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
                    _CommandKind.LEGEND_BACKGROUND,
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
                ref color = resolved_colors[order_index]
                if figure._series_is_line(order_index):
                    commands.append(
                        _styled_line_command(
                            _CommandKind.LEGEND_LINE,
                            glyph_x,
                            center_y,
                            glyph_x + 16.0,
                            center_y,
                            color,
                            style.line_width(),
                            style.line_style(),
                        )
                    )
                else:
                    commands.append(
                        _marker_command(
                            _CommandKind.LEGEND_MARKER,
                            glyph_x + 8.0,
                            center_y,
                            color,
                            -1,
                            style.marker_style(),
                        )
                    )
                commands.append(
                    _text_command(
                        _CommandKind.LEGEND_TEXT,
                        glyph_x + 21.0,
                        center_y + 3.0,
                        label^,
                    )
                )
                row_index += 1
    return _RenderPlan(
        width,
        height,
        area.x(),
        area.y(),
        area.width(),
        area.height(),
        commands^,
    )


def _semantic_class(command: _DrawCommand) -> String:
    """Return the stable semantic class derived only during SVG encoding."""
    if command.kind._value == _CommandKind.BACKGROUND._value:
        return String("sen-background")
    if command.kind._value == _CommandKind.FRAME._value:
        return String("sen-frame")
    if command.kind._value == _CommandKind.AXIS._value:
        return String("sen-axis")
    if command.kind._value == _CommandKind.TICK._value:
        return String("sen-tick")
    if (
        command.kind._value == _CommandKind.X_LABEL._value
        or command.kind._value == _CommandKind.Y_LABEL._value
    ):
        return String("sen-tick-label")
    if command.kind._value == _CommandKind.TITLE._value:
        return String("sen-title")
    if command.kind._value == _CommandKind.X_TITLE._value:
        return String("sen-x-label")
    if command.kind._value == _CommandKind.Y_TITLE._value:
        return String("sen-y-label")
    if command.kind._value == _CommandKind.GRID._value:
        return String("sen-grid")
    if (
        command.kind._value == _CommandKind.SERIES._value
        or command.kind._value == _CommandKind.MARKER._value
    ):
        return String("sen-series-") + String(command.series_index)
    if command.kind._value == _CommandKind.LEGEND_BACKGROUND._value:
        return String("sen-legend")
    return String("sen-legend-item")


def _append_rect(
    mut svg: String,
    command: _DrawCommand,
    fill: StringSlice,
    stroke: StringSlice,
) raises:
    svg += '  <rect class="'
    svg += _semantic_class(command)
    svg += '" x="'
    svg += _format_svg_number(command.x1)
    svg += '" y="'
    svg += _format_svg_number(command.y1)
    svg += '" width="'
    svg += _format_svg_number(command.x2)
    svg += '" height="'
    svg += _format_svg_number(command.y2)
    svg += '" fill="'
    svg += fill
    svg += '"'
    if stroke.byte_length() != 0:
        svg += ' stroke="'
        svg += stroke
        svg += '" stroke-width="1"'
    svg += "/>\n"


def _append_line(mut svg: String, command: _DrawCommand) raises:
    svg += '  <line class="'
    svg += _semantic_class(command)
    svg += '" x1="'
    svg += _format_svg_number(command.x1)
    svg += '" y1="'
    svg += _format_svg_number(command.y1)
    svg += '" x2="'
    svg += _format_svg_number(command.x2)
    svg += '" y2="'
    svg += _format_svg_number(command.y2)
    if command.kind._value == _CommandKind.GRID._value:
        svg += '" stroke="#e0e0e0" stroke-width="1"/>\n'
    else:
        svg += '" stroke="#222222" stroke-width="1"/>\n'


def _append_styled_line(mut svg: String, command: _DrawCommand) raises:
    svg += '  <line class="'
    svg += _semantic_class(command)
    svg += '" x1="'
    svg += _format_svg_number(command.x1)
    svg += '" y1="'
    svg += _format_svg_number(command.y1)
    svg += '" x2="'
    svg += _format_svg_number(command.x2)
    svg += '" y2="'
    svg += _format_svg_number(command.y2)
    svg += '" stroke="'
    svg += command.color
    svg += '" stroke-width="'
    svg += _format_svg_number(command.line_width)
    svg += '"'
    if command.line_style == LineStyle.DASHED:
        svg += ' stroke-dasharray="6 3"'
    elif command.line_style == LineStyle.DOTTED:
        svg += ' stroke-dasharray="1.5 2.5"'
    elif command.line_style == LineStyle.DASH_DOT:
        svg += ' stroke-dasharray="6 3 1.5 3"'
    svg += "/>\n"


def _append_text(mut svg: String, command: _DrawCommand) raises:
    svg += '  <text class="'
    svg += _semantic_class(command)
    svg += '" x="'
    svg += _format_svg_number(command.x1)
    svg += '" y="'
    svg += _format_svg_number(command.y1)
    svg += '"'
    if command.kind._value == _CommandKind.Y_TITLE._value:
        svg += ' transform="rotate(-90 '
        svg += _format_svg_number(command.x1)
        svg += " "
        svg += _format_svg_number(command.y1)
        svg += ')"'
    svg += ' fill="#222222" font-family="sans-serif" font-size="'
    if command.kind._value == _CommandKind.TITLE._value:
        svg += "12"
    elif (
        command.kind._value == _CommandKind.X_TITLE._value
        or command.kind._value == _CommandKind.Y_TITLE._value
    ):
        svg += "10"
    else:
        svg += "8"
    svg += '"'
    if (
        command.kind._value == _CommandKind.X_LABEL._value
        or command.kind._value == _CommandKind.TITLE._value
        or command.kind._value == _CommandKind.X_TITLE._value
        or command.kind._value == _CommandKind.Y_TITLE._value
    ):
        svg += ' text-anchor="middle"'
    elif command.kind._value == _CommandKind.LEGEND_TEXT._value:
        svg += ' text-anchor="start"'
    else:
        svg += ' text-anchor="end"'
    svg += ">"
    svg += _escape_xml(command.text)
    svg += "</text>\n"


def _append_polyline(mut svg: String, command: _DrawCommand) raises:
    svg += '    <polyline class="'
    svg += _semantic_class(command)
    svg += '" points="'
    for index in range(len(command.points)):
        if index > 0:
            svg += " "
        svg += _format_svg_number(command.points[index].x)
        svg += ","
        svg += _format_svg_number(command.points[index].y)
    svg += '" fill="none" stroke="'
    svg += command.color
    svg += '" stroke-width="'
    svg += _format_svg_number(command.line_width)
    svg += '"'
    if command.line_style == LineStyle.DASHED:
        svg += ' stroke-dasharray="6 3"'
    elif command.line_style == LineStyle.DOTTED:
        svg += ' stroke-dasharray="1.5 2.5"'
    elif command.line_style == LineStyle.DASH_DOT:
        svg += ' stroke-dasharray="6 3 1.5 3"'
    svg += "/>\n"


def _append_polygon_point(
    mut svg: String, center_x: Float64, center_y: Float64, dx: Float64, dy: Float64
) raises:
    svg += _format_svg_number(center_x + dx)
    svg += ","
    svg += _format_svg_number(center_y + dy)


def _append_marker_line(
    mut svg: String,
    indent: StringSlice,
    css_class: StringSlice,
    x1: Float64,
    y1: Float64,
    x2: Float64,
    y2: Float64,
    color: StringSlice,
) raises:
    svg += indent
    svg += '<line class="'
    svg += css_class
    svg += '" x1="'
    svg += _format_svg_number(x1)
    svg += '" y1="'
    svg += _format_svg_number(y1)
    svg += '" x2="'
    svg += _format_svg_number(x2)
    svg += '" y2="'
    svg += _format_svg_number(y2)
    svg += '" stroke="'
    svg += color
    svg += '" stroke-width="'
    svg += _format_svg_number(1.5)
    svg += '"/>\n'


def _append_marker(mut svg: String, command: _DrawCommand) raises:
    """Encode fixed marker geometry; ``NONE`` falls back to a visible circle."""
    var indent = String("    ")
    if command.kind._value == _CommandKind.LEGEND_MARKER._value:
        indent = String("  ")
    var color = command.color.copy()
    var css_class = _semantic_class(command)
    var marker = command.marker_style
    if marker == MarkerStyle.NONE or marker == MarkerStyle.CIRCLE:
        svg += indent
        svg += '<circle class="'
        svg += css_class
        svg += '" cx="'
        svg += _format_svg_number(command.x1)
        svg += '" cy="'
        svg += _format_svg_number(command.y1)
        svg += '" r="'
        svg += _format_svg_number(2.5)
        svg += '" fill="'
        svg += color
        svg += '"/>\n'
    elif marker == MarkerStyle.SQUARE:
        svg += indent
        svg += '<rect class="'
        svg += css_class
        svg += '" x="'
        svg += _format_svg_number(command.x1 - 2.5)
        svg += '" y="'
        svg += _format_svg_number(command.y1 - 2.5)
        svg += '" width="'
        svg += _format_svg_number(5.0)
        svg += '" height="'
        svg += _format_svg_number(5.0)
        svg += '" fill="'
        svg += color
        svg += '"/>\n'
    elif marker == MarkerStyle.TRIANGLE:
        svg += indent
        svg += '<polygon class="'
        svg += css_class
        svg += '" points="'
        _append_polygon_point(svg, command.x1, command.y1, 0.0, -2.5)
        svg += " "
        _append_polygon_point(svg, command.x1, command.y1, 2.5, 2.5)
        svg += " "
        _append_polygon_point(svg, command.x1, command.y1, -2.5, 2.5)
        svg += '" fill="'
        svg += color
        svg += '"/>\n'
    elif marker == MarkerStyle.DIAMOND:
        svg += indent
        svg += '<polygon class="'
        svg += css_class
        svg += '" points="'
        _append_polygon_point(svg, command.x1, command.y1, 0.0, -2.5)
        svg += " "
        _append_polygon_point(svg, command.x1, command.y1, 2.5, 0.0)
        svg += " "
        _append_polygon_point(svg, command.x1, command.y1, 0.0, 2.5)
        svg += " "
        _append_polygon_point(svg, command.x1, command.y1, -2.5, 0.0)
        svg += '" fill="'
        svg += color
        svg += '"/>\n'
    elif marker == MarkerStyle.PLUS:
        _append_marker_line(
            svg,
            indent,
            css_class,
            command.x1 - 2.5,
            command.y1,
            command.x1 + 2.5,
            command.y1,
            color,
        )
        _append_marker_line(
            svg,
            indent,
            css_class,
            command.x1,
            command.y1 - 2.5,
            command.x1,
            command.y1 + 2.5,
            color,
        )
    elif marker == MarkerStyle.CROSS:
        _append_marker_line(
            svg,
            indent,
            css_class,
            command.x1 - 2.5,
            command.y1 - 2.5,
            command.x1 + 2.5,
            command.y1 + 2.5,
            color,
        )
        _append_marker_line(
            svg,
            indent,
            css_class,
            command.x1 - 2.5,
            command.y1 + 2.5,
            command.x1 + 2.5,
            command.y1 - 2.5,
            color,
        )
    else:
        svg += indent
        svg += '<polygon class="'
        svg += css_class
        svg += '" points="'
        # Five-point star offsets are exact Float64 literals: outer radius 2.9,
        # inner radius 1.1, with the first vertex pointing upward.
        _append_polygon_point(svg, command.x1, command.y1, 0.0, -2.9)
        svg += " "
        _append_polygon_point(svg, command.x1, command.y1, 0.6465637775, -0.8899186938)
        svg += " "
        _append_polygon_point(svg, command.x1, command.y1, 2.758063897, -0.8961492837)
        svg += " "
        _append_polygon_point(svg, command.x1, command.y1, 1.046162168, 0.3399186938)
        svg += " "
        _append_polygon_point(svg, command.x1, command.y1, 1.704577232, 2.346149284)
        svg += " "
        _append_polygon_point(svg, command.x1, command.y1, 0.0, 1.1)
        svg += " "
        _append_polygon_point(svg, command.x1, command.y1, -1.704577232, 2.346149284)
        svg += " "
        _append_polygon_point(svg, command.x1, command.y1, -1.046162168, 0.3399186938)
        svg += " "
        _append_polygon_point(svg, command.x1, command.y1, -2.758063897, -0.8961492837)
        svg += " "
        _append_polygon_point(svg, command.x1, command.y1, -0.6465637775, -0.8899186938)
        svg += '" fill="'
        svg += color
        svg += '"/>\n'


def _encode_svg(plan: _RenderPlan) raises -> String:
    """Encode commands with fixed per-element attribute ordering."""
    var svg = String('<svg xmlns="http://www.w3.org/2000/svg" width="')
    svg += _format_svg_number(plan.width)
    svg += '" height="'
    svg += _format_svg_number(plan.height)
    svg += '" viewBox="0 0 '
    svg += _format_svg_number(plan.width)
    svg += " "
    svg += _format_svg_number(plan.height)
    svg += '">\n'
    svg += "  <defs>\n"
    svg += '    <clipPath id="sen-plot-area">\n'
    svg += '      <rect x="'
    svg += _format_svg_number(plan.plot_x)
    svg += '" y="'
    svg += _format_svg_number(plan.plot_y)
    svg += '" width="'
    svg += _format_svg_number(plan.plot_width)
    svg += '" height="'
    svg += _format_svg_number(plan.plot_height)
    svg += '"/>\n'
    svg += "    </clipPath>\n"
    svg += "  </defs>\n"
    var series_group_open = False
    for index in range(len(plan.commands)):
        ref command = plan.commands[index]
        var is_series = (
            command.kind._value == _CommandKind.SERIES._value
            or command.kind._value == _CommandKind.MARKER._value
        )
        if is_series and not series_group_open:
            svg += '  <g clip-path="url(#sen-plot-area)">\n'
            series_group_open = True
        elif not is_series and series_group_open:
            svg += "  </g>\n"
            series_group_open = False
        if command.kind._value == _CommandKind.BACKGROUND._value:
            _append_rect(svg, command, "#ffffff", "")
        elif command.kind._value == _CommandKind.FRAME._value:
            _append_rect(svg, command, "none", "#d0d0d0")
        elif command.kind._value == _CommandKind.LEGEND_BACKGROUND._value:
            _append_rect(svg, command, "#ffffff", "#d0d0d0")
        elif (
            command.kind._value == _CommandKind.AXIS._value
            or command.kind._value == _CommandKind.TICK._value
            or command.kind._value == _CommandKind.GRID._value
        ):
            _append_line(svg, command)
        elif (
            command.kind._value == _CommandKind.X_LABEL._value
            or command.kind._value == _CommandKind.Y_LABEL._value
            or command.kind._value == _CommandKind.TITLE._value
            or command.kind._value == _CommandKind.X_TITLE._value
            or command.kind._value == _CommandKind.Y_TITLE._value
            or command.kind._value == _CommandKind.LEGEND_TEXT._value
        ):
            _append_text(svg, command)
        elif command.kind._value == _CommandKind.SERIES._value:
            _append_polyline(svg, command)
        elif command.kind._value == _CommandKind.LEGEND_LINE._value:
            _append_styled_line(svg, command)
        else:
            _append_marker(svg, command)
    if series_group_open:
        svg += "  </g>\n"
    svg += "</svg>\n"
    return svg^


def render_svg(
    figure: Figure,
    width: Float64,
    height: Float64,
    margins: Margins,
) raises -> String:
    """Render ``figure`` to a complete deterministic SVG document.

    Empty figures are rejected. Nonconstant data bounds receive a five-percent
    margin on each side; each remaining constant axis is padded by the larger of
    0.5 or five percent of the constant's magnitude before ticks and scales are
    built. A logarithmic axis instead receives five-percent padding in base-10
    exponent space, while a constant logarithmic domain receives one decade on
    either side. Logarithmic rendering rejects a non-positive explicit lower
    limit or the first non-positive per-series minimum in insertion order, with
    axis, series, and value context. Explicit axis limits replace autoscale rules
    exactly on their own axis. Invalid figure sizes or margins and any unsafe
    derived domain also raise before encoding.
    Automatic palette slots are resolved while walking insertion order; only
    automatic series advance the counter, which starts at zero and cycles modulo
    six. Legend rows are 14 units high with five-unit vertical padding; width is
    five units per Unicode codepoint plus six-unit side paddings, a 16-unit glyph,
    and a five-unit glyph/text gap, avoiding platform text measurement. A
    nonempty title adds a fixed 18-unit top band to ``margins``; nonempty x- and
    y-axis labels add fixed 14-unit bottom and left bands. Series geometry is
    always clipped to the plot-area rectangle.
    Geometry uses fixed-point formatting with at most three fractional digits,
    half-away-from-zero rounding, stripped trailing zeros, normalized negative
    zero, and no exponent notation. The hand-written encoder emits a fixed
    element order and fixed left-to-right attribute order. Every drawing element
    receives its stable semantic ``sen-*`` class as the first attribute while
    retaining inline presentation attributes. The returned document ends with
    exactly one newline after ``</svg>``.
    """
    return _encode_svg(_lower_figure(figure, width, height, margins))


def render_svg(
    figure: Figure,
    width: Float64 = 640.0,
    height: Float64 = 480.0,
) raises -> String:
    """Render with a 640x480 default size and margins of 40/12/12/28.

    A nonempty title reserves a deterministic 18-unit top band. Nonempty x- and
    y-axis labels reserve deterministic 14-unit bottom and left bands.
    """
    return render_svg(figure, width, height, Margins(40.0, 12.0, 12.0, 28.0))


def save_svg(path: StringSlice, svg: StringSlice) raises:
    """Write supplied SVG bytes; missing parent directories are created."""
    var slash_index = path.byte_length() - 1
    while slash_index >= 0:
        if path[byte = slash_index : slash_index + 1] == "/":
            break
        slash_index -= 1
    if slash_index > 0:
        makedirs(path[byte=:slash_index], exist_ok=True)
    with open(path, "w") as output:
        output.write(svg)
