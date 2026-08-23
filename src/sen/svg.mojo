"""Deterministic SVG rendering for scientific figures."""

from std.math import floor, isfinite
from std.os import makedirs

from .layout import Margins
from .lowering import build_render_plan
from .render_plan import CommandKind, DrawCommand, RenderPlan
from .series import Figure
from .style import LineStyle, MarkerStyle, _palette_color


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


def _append_svg_number(mut output: String, value: Float64) raises:
    """Append fixed SVG geometry without allocating a temporary number string.

    This is byte-equivalent to ``_format_svg_number``. It specializes the hot
    three-decimal geometry path so large line and scatter documents write their
    digits directly into the destination buffer.
    """
    if not isfinite(value):
        raise Error("SVG numbers must be finite")
    var magnitude = abs(value)
    if magnitude > 9.0e15:
        raise Error("SVG fixed-decimal value exceeds the supported magnitude")
    var rounded = Int(floor(magnitude * 1000.0 + 0.5))
    if rounded == 0:
        output += "0"
        return
    if value < 0.0:
        output += "-"
    output.write(rounded // 1000)
    var remainder = rounded % 1000
    if remainder == 0:
        return
    var fractional_width = 3
    while remainder % 10 == 0:
        remainder //= 10
        fractional_width -= 1
    var digit_count = 1
    if remainder >= 10:
        digit_count = 2
    if remainder >= 100:
        digit_count = 3
    output += "."
    for _ in range(fractional_width - digit_count):
        output += "0"
    output.write(remainder)


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


def _semantic_class(command: DrawCommand) -> String:
    """Return the stable semantic class derived only during SVG encoding."""
    if command.kind._value == CommandKind.BACKGROUND._value:
        return String("sen-background")
    if command.kind._value == CommandKind.FRAME._value:
        return String("sen-frame")
    if command.kind._value == CommandKind.AXIS._value:
        return String("sen-axis")
    if command.kind._value == CommandKind.TICK._value:
        return String("sen-tick")
    if (
        command.kind._value == CommandKind.X_LABEL._value
        or command.kind._value == CommandKind.Y_LABEL._value
    ):
        return String("sen-tick-label")
    if command.kind._value == CommandKind.TITLE._value:
        return String("sen-title")
    if command.kind._value == CommandKind.X_TITLE._value:
        return String("sen-x-label")
    if command.kind._value == CommandKind.Y_TITLE._value:
        return String("sen-y-label")
    if command.kind._value == CommandKind.GRID._value:
        return String("sen-grid")
    if (
        command.kind._value == CommandKind.SERIES._value
        or command.kind._value == CommandKind.AREA._value
        or command.kind._value == CommandKind.MARKER._value
        or command.kind._value == CommandKind.RECTANGLE._value
    ):
        return String("sen-series-") + String(command.series_index)
    if command.kind._value == CommandKind.LEGEND_BACKGROUND._value:
        return String("sen-legend")
    return String("sen-legend-item")


def _append_rect(
    mut svg: String,
    command: DrawCommand,
    fill: StringSlice,
    stroke: StringSlice,
) raises:
    if command.kind._value == CommandKind.RECTANGLE._value:
        svg += '    <rect class="'
    else:
        svg += '  <rect class="'
    svg += _semantic_class(command)
    svg += '" x="'
    _append_svg_number(svg, command.x1)
    svg += '" y="'
    _append_svg_number(svg, command.y1)
    svg += '" width="'
    _append_svg_number(svg, command.x2)
    svg += '" height="'
    _append_svg_number(svg, command.y2)
    svg += '" fill="'
    svg += fill
    svg += '"'
    if stroke.byte_length() != 0:
        svg += ' stroke="'
        svg += stroke
        svg += '" stroke-width="1"'
    svg += "/>\n"


def _append_line(mut svg: String, command: DrawCommand) raises:
    svg += '  <line class="'
    svg += _semantic_class(command)
    svg += '" x1="'
    _append_svg_number(svg, command.x1)
    svg += '" y1="'
    _append_svg_number(svg, command.y1)
    svg += '" x2="'
    _append_svg_number(svg, command.x2)
    svg += '" y2="'
    _append_svg_number(svg, command.y2)
    if command.kind._value == CommandKind.GRID._value:
        svg += '" stroke="#e0e0e0" stroke-width="1"/>\n'
    else:
        svg += '" stroke="#222222" stroke-width="1"/>\n'


def _append_styled_line(mut svg: String, command: DrawCommand) raises:
    svg += '  <line class="'
    svg += _semantic_class(command)
    svg += '" x1="'
    _append_svg_number(svg, command.x1)
    svg += '" y1="'
    _append_svg_number(svg, command.y1)
    svg += '" x2="'
    _append_svg_number(svg, command.x2)
    svg += '" y2="'
    _append_svg_number(svg, command.y2)
    svg += '" stroke="'
    svg += command.color
    svg += '" stroke-width="'
    _append_svg_number(svg, command.line_width)
    svg += '"'
    if command.line_style == LineStyle.DASHED:
        svg += ' stroke-dasharray="6 3"'
    elif command.line_style == LineStyle.DOTTED:
        svg += ' stroke-dasharray="1.5 2.5"'
    elif command.line_style == LineStyle.DASH_DOT:
        svg += ' stroke-dasharray="6 3 1.5 3"'
    svg += "/>\n"


def _append_text(mut svg: String, command: DrawCommand) raises:
    svg += '  <text class="'
    svg += _semantic_class(command)
    svg += '" x="'
    _append_svg_number(svg, command.x1)
    svg += '" y="'
    _append_svg_number(svg, command.y1)
    svg += '"'
    if command.kind._value == CommandKind.Y_TITLE._value:
        svg += ' transform="rotate(-90 '
        _append_svg_number(svg, command.x1)
        svg += " "
        _append_svg_number(svg, command.y1)
        svg += ')"'
    svg += ' fill="#222222" font-family="sans-serif" font-size="'
    if command.kind._value == CommandKind.TITLE._value:
        svg += "12"
    elif (
        command.kind._value == CommandKind.X_TITLE._value
        or command.kind._value == CommandKind.Y_TITLE._value
    ):
        svg += "10"
    else:
        svg += "8"
    svg += '"'
    if (
        command.kind._value == CommandKind.X_LABEL._value
        or command.kind._value == CommandKind.TITLE._value
        or command.kind._value == CommandKind.X_TITLE._value
        or command.kind._value == CommandKind.Y_TITLE._value
    ):
        svg += ' text-anchor="middle"'
    elif command.kind._value == CommandKind.LEGEND_TEXT._value:
        svg += ' text-anchor="start"'
    else:
        svg += ' text-anchor="end"'
    svg += ">"
    svg += _escape_xml(command.text)
    svg += "</text>\n"


def _append_polyline(mut svg: String, command: DrawCommand) raises:
    svg += '    <polyline class="'
    svg += _semantic_class(command)
    svg += '" points="'
    for index in range(len(command.points)):
        if index > 0:
            svg += " "
        _append_svg_number(svg, command.points[index].x)
        svg += ","
        _append_svg_number(svg, command.points[index].y)
    svg += '" fill="none" stroke="'
    svg += command.color
    svg += '" stroke-width="'
    _append_svg_number(svg, command.line_width)
    svg += '"'
    if command.line_style == LineStyle.DASHED:
        svg += ' stroke-dasharray="6 3"'
    elif command.line_style == LineStyle.DOTTED:
        svg += ' stroke-dasharray="1.5 2.5"'
    elif command.line_style == LineStyle.DASH_DOT:
        svg += ' stroke-dasharray="6 3 1.5 3"'
    svg += "/>\n"


def _append_area(mut svg: String, command: DrawCommand) raises:
    svg += '    <polygon class="'
    svg += _semantic_class(command)
    svg += '" points="'
    for index in range(len(command.points)):
        if index > 0:
            svg += " "
        _append_svg_number(svg, command.points[index].x)
        svg += ","
        _append_svg_number(svg, command.points[index].y)
    svg += '" fill="'
    svg += command.color
    svg += '" fill-opacity="0.35" stroke="'
    svg += command.color
    svg += '" stroke-width="'
    _append_svg_number(svg, command.line_width)
    svg += '"'
    if command.line_style == LineStyle.DASHED:
        svg += ' stroke-dasharray="6 3"'
    elif command.line_style == LineStyle.DOTTED:
        svg += ' stroke-dasharray="1.5 2.5"'
    elif command.line_style == LineStyle.DASH_DOT:
        svg += ' stroke-dasharray="6 3 1.5 3"'
    svg += "/>\n"


def _append_area_legend(mut svg: String, command: DrawCommand) raises:
    """Encode an area key with the same fill, opacity, outline, and dash."""
    svg += '  <rect class="'
    svg += _semantic_class(command)
    svg += '" x="'
    _append_svg_number(svg, command.x1)
    svg += '" y="'
    _append_svg_number(svg, command.y1)
    svg += '" width="'
    _append_svg_number(svg, command.x2)
    svg += '" height="'
    _append_svg_number(svg, command.y2)
    svg += '" fill="'
    svg += command.color
    svg += '" fill-opacity="0.35" stroke="'
    svg += command.color
    svg += '" stroke-width="'
    _append_svg_number(svg, command.line_width)
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
    _append_svg_number(svg, center_x + dx)
    svg += ","
    _append_svg_number(svg, center_y + dy)


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
    _append_svg_number(svg, x1)
    svg += '" y1="'
    _append_svg_number(svg, y1)
    svg += '" x2="'
    _append_svg_number(svg, x2)
    svg += '" y2="'
    _append_svg_number(svg, y2)
    svg += '" stroke="'
    svg += color
    svg += '" stroke-width="'
    _append_svg_number(svg, 1.5)
    svg += '"/>\n'


def _append_marker(mut svg: String, command: DrawCommand) raises:
    """Encode fixed marker geometry; ``NONE`` falls back to a visible circle."""
    var indent = String("    ")
    if command.kind._value == CommandKind.LEGEND_MARKER._value:
        indent = String("  ")
    var color = command.color.copy()
    if color.byte_length() == 0:
        color = _palette_color(command.palette_slot)
    var css_class = _semantic_class(command)
    var marker = command.marker_style
    if marker == MarkerStyle.NONE or marker == MarkerStyle.CIRCLE:
        svg += indent
        svg += '<circle class="'
        svg += css_class
        svg += '" cx="'
        _append_svg_number(svg, command.x1)
        svg += '" cy="'
        _append_svg_number(svg, command.y1)
        svg += '" r="'
        _append_svg_number(svg, 2.5)
        svg += '" fill="'
        svg += color
        svg += '"/>\n'
    elif marker == MarkerStyle.SQUARE:
        svg += indent
        svg += '<rect class="'
        svg += css_class
        svg += '" x="'
        _append_svg_number(svg, command.x1 - 2.5)
        svg += '" y="'
        _append_svg_number(svg, command.y1 - 2.5)
        svg += '" width="'
        _append_svg_number(svg, 5.0)
        svg += '" height="'
        _append_svg_number(svg, 5.0)
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


def _encode_svg(plan: RenderPlan) raises -> String:
    """Encode commands with fixed per-element attribute ordering."""
    var svg = String('<svg xmlns="http://www.w3.org/2000/svg" width="')
    _append_svg_number(svg, plan.width)
    svg += '" height="'
    _append_svg_number(svg, plan.height)
    svg += '" viewBox="0 0 '
    _append_svg_number(svg, plan.width)
    svg += " "
    _append_svg_number(svg, plan.height)
    svg += '">\n'
    svg += "  <defs>\n"
    svg += '    <clipPath id="sen-plot-area">\n'
    svg += '      <rect x="'
    _append_svg_number(svg, plan.plot_x)
    svg += '" y="'
    _append_svg_number(svg, plan.plot_y)
    svg += '" width="'
    _append_svg_number(svg, plan.plot_width)
    svg += '" height="'
    _append_svg_number(svg, plan.plot_height)
    svg += '"/>\n'
    svg += "    </clipPath>\n"
    svg += "  </defs>\n"
    var series_group_open = False
    for index in range(len(plan.commands)):
        ref command = plan.commands[index]
        var is_series = (
            command.kind._value == CommandKind.SERIES._value
            or command.kind._value == CommandKind.AREA._value
            or command.kind._value == CommandKind.MARKER._value
            or command.kind._value == CommandKind.RECTANGLE._value
        )
        if is_series and not series_group_open:
            svg += '  <g clip-path="url(#sen-plot-area)">\n'
            series_group_open = True
        elif not is_series and series_group_open:
            svg += "  </g>\n"
            series_group_open = False
        if command.kind._value == CommandKind.BACKGROUND._value:
            _append_rect(svg, command, "#ffffff", "")
        elif command.kind._value == CommandKind.FRAME._value:
            _append_rect(svg, command, "none", "#d0d0d0")
        elif command.kind._value == CommandKind.LEGEND_BACKGROUND._value:
            _append_rect(svg, command, "#ffffff", "#d0d0d0")
        elif command.kind._value == CommandKind.RECTANGLE._value:
            _append_rect(svg, command, command.color, "")
        elif command.kind._value == CommandKind.LEGEND_RECTANGLE._value:
            _append_rect(svg, command, command.color, "")
        elif command.kind._value == CommandKind.LEGEND_AREA._value:
            _append_area_legend(svg, command)
        elif (
            command.kind._value == CommandKind.AXIS._value
            or command.kind._value == CommandKind.TICK._value
            or command.kind._value == CommandKind.GRID._value
        ):
            _append_line(svg, command)
        elif (
            command.kind._value == CommandKind.X_LABEL._value
            or command.kind._value == CommandKind.Y_LABEL._value
            or command.kind._value == CommandKind.TITLE._value
            or command.kind._value == CommandKind.X_TITLE._value
            or command.kind._value == CommandKind.Y_TITLE._value
            or command.kind._value == CommandKind.LEGEND_TEXT._value
        ):
            _append_text(svg, command)
        elif command.kind._value == CommandKind.SERIES._value:
            _append_polyline(svg, command)
        elif command.kind._value == CommandKind.AREA._value:
            _append_area(svg, command)
        elif command.kind._value == CommandKind.LEGEND_LINE._value:
            _append_styled_line(svg, command)
        else:
            _append_marker(svg, command)
    if series_group_open:
        svg += "  </g>\n"
    svg += "</svg>\n"
    return svg^


def encode_svg(plan: RenderPlan) raises -> String:
    """Validate and encode an already-built renderer-neutral plan as SVG.

    Use this boundary when one ``RenderPlan`` is shared with several encoders or
    inspected before output.  The plan is not rebuilt and no file I/O occurs.
    Direct low-level mutation is checked before any SVG bytes are returned.
    """
    plan.validate()
    return _encode_svg(plan)


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
    return _encode_svg(build_render_plan(figure, width, height, margins))


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


def write_svg(path: StringSlice, svg: StringSlice) raises:
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


def save_svg(path: StringSlice, svg: StringSlice) raises:
    """Compatibility alias for ``write_svg``."""
    write_svg(path, svg)
