"""Deterministic SVG rendering for scientific figures."""

from std.collections import List
from std.math import floor, isfinite

from .layout import Margins, plot_area
from .scale import LinearScale, linear_ticks
from .series import Figure


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

    def __init__(
        out self,
        kind: _CommandKind,
        x1: Float64,
        y1: Float64,
        x2: Float64,
        y2: Float64,
        var points: List[_PlanPoint],
        var text: String,
    ):
        self.kind = kind
        self.x1 = x1
        self.y1 = y1
        self.x2 = x2
        self.y2 = y2
        self.points = points^
        self.text = text^


struct _RenderPlan:
    var width: Float64
    var height: Float64
    var commands: List[_DrawCommand]

    def __init__(
        out self,
        width: Float64,
        height: Float64,
        var commands: List[_DrawCommand],
    ):
        self.width = width
        self.height = height
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
    )


def _polyline_command(var points: List[_PlanPoint]) -> _DrawCommand:
    return _DrawCommand(
        _CommandKind.SERIES,
        0.0,
        0.0,
        0.0,
        0.0,
        points^,
        String(),
    )


def _marker_command(x: Float64, y: Float64) -> _DrawCommand:
    return _DrawCommand(
        _CommandKind.MARKER,
        x,
        y,
        0.0,
        0.0,
        _empty_points(),
        String(),
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
        raise Error("constant ", axis_name, " domain cannot be padded safely")
    return (padded_lo, padded_hi)


def _decimal_factor(precision: Int) raises -> Int:
    if precision < 0 or precision > 9:
        raise Error("SVG decimal precision must be between zero and nine")
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
        raise Error("SVG numbers must be finite")
    var factor = _decimal_factor(precision)
    var magnitude = abs(value)
    if magnitude > 9.0e18 / Float64(factor):
        raise Error("SVG fixed-decimal value exceeds the supported magnitude")
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


def _tick_step(ticks: List[Float64], domain_span: Float64) -> Float64:
    if len(ticks) >= 2:
        return abs(ticks[1] - ticks[0])
    return abs(domain_span)


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
    var bounds = figure.bounds()
    var x_domain = _padded_domain(bounds.x_min(), bounds.x_max(), "x")
    var y_domain = _padded_domain(bounds.y_min(), bounds.y_max(), "y")
    var x_scale = LinearScale(
        x_domain[0],
        x_domain[1],
        area.x(),
        area.x() + area.width(),
    )
    var y_scale = LinearScale(
        y_domain[0],
        y_domain[1],
        area.y() + area.height(),
        area.y(),
    )
    var x_ticks = linear_ticks(x_domain[0], x_domain[1])
    var y_ticks = linear_ticks(y_domain[0], y_domain[1])
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
        var x = x_scale.map(tick)
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
        var y = y_scale.map(tick)
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

    for order_index in range(figure._series_count()):
        var series_index = figure._series_index(order_index)
        if figure._series_is_line(order_index):
            ref line = figure.line(series_index)
            for segment_index in range(line.segment_count()):
                var points = List[_PlanPoint]()
                for point_index in range(line.segment_point_count(segment_index)):
                    var point = line.segment_point(segment_index, point_index)
                    points.append(
                        _PlanPoint(x_scale.map(point.x()), y_scale.map(point.y()))
                    )
                commands.append(_polyline_command(points^))
        else:
            ref scatter = figure.scatter(series_index)
            for point_index in range(scatter.point_count()):
                var point = scatter.point(point_index)
                commands.append(
                    _marker_command(
                        x_scale.map(point.x()),
                        y_scale.map(point.y()),
                    )
                )
    return _RenderPlan(width, height, commands^)


def _append_rect(
    mut svg: String,
    command: _DrawCommand,
    fill: StringSlice,
    stroke: StringSlice,
) raises:
    svg += '  <rect x="'
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
    svg += '  <line x1="'
    svg += _format_svg_number(command.x1)
    svg += '" y1="'
    svg += _format_svg_number(command.y1)
    svg += '" x2="'
    svg += _format_svg_number(command.x2)
    svg += '" y2="'
    svg += _format_svg_number(command.y2)
    svg += '" stroke="#222222" stroke-width="1"/>\n'


def _append_text(mut svg: String, command: _DrawCommand) raises:
    svg += '  <text x="'
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
    else:
        svg += ' text-anchor="end"'
    svg += ">"
    svg += _escape_xml(command.text)
    svg += "</text>\n"


def _append_polyline(mut svg: String, command: _DrawCommand) raises:
    svg += '  <polyline points="'
    for index in range(len(command.points)):
        if index > 0:
            svg += " "
        svg += _format_svg_number(command.points[index].x)
        svg += ","
        svg += _format_svg_number(command.points[index].y)
    svg += '" fill="none" stroke="#2563eb" stroke-width="1.5"/>\n'


def _append_marker(mut svg: String, command: _DrawCommand) raises:
    svg += '  <circle cx="'
    svg += _format_svg_number(command.x1)
    svg += '" cy="'
    svg += _format_svg_number(command.y1)
    svg += '" r="2.5" fill="#2563eb"/>\n'


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
    for index in range(len(plan.commands)):
        ref command = plan.commands[index]
        if command.kind._value == _CommandKind.BACKGROUND._value:
            _append_rect(svg, command, "#ffffff", "")
        elif command.kind._value == _CommandKind.FRAME._value:
            _append_rect(svg, command, "none", "#d0d0d0")
        elif (
            command.kind._value == _CommandKind.AXIS._value
            or command.kind._value == _CommandKind.TICK._value
        ):
            _append_line(svg, command)
        elif (
            command.kind._value == _CommandKind.X_LABEL._value
            or command.kind._value == _CommandKind.Y_LABEL._value
            or command.kind._value == _CommandKind.TITLE._value
            or command.kind._value == _CommandKind.X_TITLE._value
            or command.kind._value == _CommandKind.Y_TITLE._value
        ):
            _append_text(svg, command)
        elif command.kind._value == _CommandKind.SERIES._value:
            _append_polyline(svg, command)
        else:
            _append_marker(svg, command)
    svg += "</svg>\n"
    return svg^


def render_svg(
    figure: Figure,
    width: Float64,
    height: Float64,
    margins: Margins,
) raises -> String:
    """Render ``figure`` to a complete deterministic SVG document.

    Empty figures are rejected. Each constant axis is padded by the larger of
    0.5 or five percent of the constant's magnitude before ticks and scales are
    built. A nonempty title adds a fixed 18-unit top band to ``margins``;
    nonempty x- and y-axis labels add fixed 14-unit bottom and left bands.
    Geometry uses fixed-point formatting with at most three fractional digits,
    half-away-from-zero rounding, stripped trailing zeros, normalized negative
    zero, and no exponent notation. The hand-written encoder emits a fixed
    element order and fixed left-to-right attribute order. The returned document
    ends with exactly one newline after ``</svg>``.
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
    """Write a previously rendered SVG string to ``path`` exactly as supplied."""
    with open(path, "w") as output:
        output.write(svg)
