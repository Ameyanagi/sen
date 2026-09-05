"""Deterministic SVG rendering for scientific figures."""

from std.math import floor, isfinite
from std.os import makedirs

from .layout import Margins
from .lowering import build_render_plan
from .render_plan import CommandKind, DrawCommand, RenderPlan
from .series import Figure
from .style import LineCap, LineJoin, LineStyle, MarkerStyle, _palette_color
from .text import TextKind
from .typst import TypstOptions, _TypstCache


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


def _escape_xml(text: StringSlice) raises -> String:
    """Escape XML entities and reject scalars forbidden by XML 1.0."""
    var escaped = String()
    for grapheme in text.codepoint_slices():
        var codepoint = 0
        for scalar in grapheme.codepoints():
            codepoint = Int(scalar.to_u32())
        var permitted = (
            codepoint == 0x09
            or codepoint == 0x0A
            or codepoint == 0x0D
            or (codepoint >= 0x20 and codepoint <= 0xD7FF)
            or (codepoint >= 0xE000 and codepoint <= 0xFFFD)
            or (codepoint >= 0x10000 and codepoint <= 0x10FFFF)
        )
        if not permitted:
            raise Error(
                "SVG text contains a scalar forbidden by XML 1.0; got U+",
                codepoint,
            )
        if grapheme == "&":
            escaped += "&amp;"
        elif grapheme == "<":
            escaped += "&lt;"
        elif grapheme == ">":
            escaped += "&gt;"
        elif grapheme == '"':
            escaped += "&quot;"
        elif grapheme == "'":
            escaped += "&apos;"
        else:
            escaped += grapheme
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
    opacity: Float64 = 1.0,
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
    if opacity != 1.0:
        svg += ' opacity="'
        _append_svg_number(svg, opacity)
        svg += '"'
    svg += "/>\n"


def _append_line(mut svg: String, command: DrawCommand, color: StringSlice) raises:
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
    svg += color
    svg += '" stroke-width="1"/>\n'


def _append_line_cap(mut svg: String, cap: LineCap):
    svg += ' stroke-linecap="'
    if cap == LineCap.BUTT:
        svg += "butt"
    elif cap == LineCap.SQUARE:
        svg += "square"
    else:
        svg += "round"
    svg += '"'


def _append_line_join(mut svg: String, join: LineJoin):
    svg += ' stroke-linejoin="'
    if join == LineJoin.MITER:
        svg += "miter"
    elif join == LineJoin.BEVEL:
        svg += "bevel"
    else:
        svg += "round"
    svg += '"'


def _append_opacity(mut svg: String, opacity: Float64) raises:
    if opacity != 1.0:
        svg += ' opacity="'
        _append_svg_number(svg, opacity)
        svg += '"'


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
    _append_line_cap(svg, command.line_cap)
    _append_line_join(svg, command.line_join)
    _append_opacity(svg, command.opacity)
    svg += "/>\n"


def _append_text(
    mut svg: String,
    command: DrawCommand,
    family: StringSlice,
    foreground: StringSlice,
) raises:
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
    svg += ' fill="'
    svg += foreground
    svg += '" font-family="'
    svg += _escape_xml(family)
    svg += '" font-size="'
    _append_svg_number(svg, command.font_size)
    svg += '"'
    if command.kind._value == CommandKind.TITLE._value:
        svg += ' font-weight="600"'
    elif (
        command.kind._value == CommandKind.X_TITLE._value
        or command.kind._value == CommandKind.Y_TITLE._value
    ):
        svg += ' font-weight="500"'
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


def _append_typst_text(
    mut svg: String,
    command: DrawCommand,
    command_index: Int,
    plan: RenderPlan,
    foreground: StringSlice,
    options: TypstOptions,
    mut cache: _TypstCache,
) raises:
    """Compile and nest one fixed-size Typst fragment at a text command."""
    # Typst source is also exposed as accessibility metadata by callers and must
    # remain valid XML even though the compiled geometry contains no source text.
    _ = _escape_xml(command.text)
    var box_width = plan.plot_width
    if command.kind == CommandKind.Y_TITLE:
        box_width = plan.plot_height
    var box_height = command.font_size * 2.4
    var points_per_logical = 72.0 / 100.0
    var compiled = cache.compile(
        command.text,
        command.font_size * points_per_logical,
        foreground,
        box_width * points_per_logical,
        box_height * points_per_logical,
        options,
    )
    var id_prefix = options.id_prefix()
    id_prefix += "-"
    id_prefix += _semantic_class(command)
    id_prefix += "-"
    id_prefix.write(command_index)
    id_prefix += "-"
    var rewritten = _rewrite_typst_ids(compiled, id_prefix)
    var nested = String(rewritten[byte=4:])
    _append_placed_typst_svg(svg, command, plan, nested^)


def _rewrite_typst_ids(compiled: StringSlice, id_prefix: StringSlice) -> String:
    """Namespace Typst definitions and their local SVG references."""
    var rewritten = String(compiled).replace('id="', 'id="' + id_prefix)
    rewritten = rewritten.replace('href="#', 'href="#' + id_prefix)
    rewritten = rewritten.replace("url(#", "url(#" + id_prefix)
    return rewritten^


def _append_placed_typst_svg(
    mut svg: String,
    command: DrawCommand,
    plan: RenderPlan,
    var nested: String,
) raises:
    """Place one already-compiled and namespaced Typst SVG document."""
    var box_width = plan.plot_width
    if command.kind == CommandKind.Y_TITLE:
        box_width = plan.plot_height
    var box_height = command.font_size * 2.4
    var x = command.x1 - box_width / 2.0
    var y = command.y1 - command.font_size * 0.3 - box_height / 2.0
    if command.kind == CommandKind.Y_TITLE:
        svg += '  <g transform="rotate(-90 '
        _append_svg_number(svg, command.x1)
        svg += " "
        _append_svg_number(svg, command.y1)
        svg += ')">\n'
        svg += "  "
    svg += '  <svg class="'
    svg += _semantic_class(command)
    svg += ' sen-typst" x="'
    _append_svg_number(svg, x)
    svg += '" y="'
    _append_svg_number(svg, y)
    svg += '"'
    # Typst emits a single root SVG with deterministic dimensions and no XML
    # declaration. Preserve its complete body while adding Sen placement.
    svg += nested
    if command.kind == CommandKind.Y_TITLE:
        svg += "  </g>\n"


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
    _append_line_cap(svg, command.line_cap)
    _append_line_join(svg, command.line_join)
    _append_opacity(svg, command.opacity)
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
    svg += '" fill-opacity="'
    _append_svg_number(svg, 0.35 * command.opacity)
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
    if command.opacity != 1.0:
        svg += ' stroke-opacity="'
        _append_svg_number(svg, command.opacity)
        svg += '"'
    _append_line_cap(svg, command.line_cap)
    _append_line_join(svg, command.line_join)
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
    svg += '" fill-opacity="'
    _append_svg_number(svg, 0.35 * command.opacity)
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
    if command.opacity != 1.0:
        svg += ' stroke-opacity="'
        _append_svg_number(svg, command.opacity)
        svg += '"'
    _append_line_cap(svg, command.line_cap)
    _append_line_join(svg, command.line_join)
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
    width: Float64,
    opacity: Float64,
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
    _append_svg_number(svg, width)
    svg += '"'
    _append_opacity(svg, opacity)
    svg += "/>\n"


def _append_marker(mut svg: String, command: DrawCommand) raises:
    """Encode configured marker geometry; ``NONE`` remains a visible circle."""
    var indent = String("    ")
    if command.kind._value == CommandKind.LEGEND_MARKER._value:
        indent = String("  ")
    var color = command.color.copy()
    if color.byte_length() == 0:
        color = _palette_color(command.palette_slot)
    var css_class = _semantic_class(command)
    var marker = command.marker_style
    var radius = command.marker_size / 2.0
    if marker == MarkerStyle.NONE or marker == MarkerStyle.CIRCLE:
        svg += indent
        svg += '<circle class="'
        svg += css_class
        svg += '" cx="'
        _append_svg_number(svg, command.x1)
        svg += '" cy="'
        _append_svg_number(svg, command.y1)
        svg += '" r="'
        _append_svg_number(svg, radius)
        svg += '" fill="'
        svg += color
        svg += '"'
        _append_opacity(svg, command.opacity)
        svg += "/>\n"
    elif marker == MarkerStyle.SQUARE:
        svg += indent
        svg += '<rect class="'
        svg += css_class
        svg += '" x="'
        _append_svg_number(svg, command.x1 - radius)
        svg += '" y="'
        _append_svg_number(svg, command.y1 - radius)
        svg += '" width="'
        _append_svg_number(svg, command.marker_size)
        svg += '" height="'
        _append_svg_number(svg, command.marker_size)
        svg += '" fill="'
        svg += color
        svg += '"'
        _append_opacity(svg, command.opacity)
        svg += "/>\n"
    elif marker == MarkerStyle.TRIANGLE:
        svg += indent
        svg += '<polygon class="'
        svg += css_class
        svg += '" points="'
        _append_polygon_point(svg, command.x1, command.y1, 0.0, -radius)
        svg += " "
        _append_polygon_point(svg, command.x1, command.y1, radius, radius)
        svg += " "
        _append_polygon_point(svg, command.x1, command.y1, -radius, radius)
        svg += '" fill="'
        svg += color
        svg += '"'
        _append_opacity(svg, command.opacity)
        svg += "/>\n"
    elif marker == MarkerStyle.DIAMOND:
        svg += indent
        svg += '<polygon class="'
        svg += css_class
        svg += '" points="'
        _append_polygon_point(svg, command.x1, command.y1, 0.0, -radius)
        svg += " "
        _append_polygon_point(svg, command.x1, command.y1, radius, 0.0)
        svg += " "
        _append_polygon_point(svg, command.x1, command.y1, 0.0, radius)
        svg += " "
        _append_polygon_point(svg, command.x1, command.y1, -radius, 0.0)
        svg += '" fill="'
        svg += color
        svg += '"'
        _append_opacity(svg, command.opacity)
        svg += "/>\n"
    elif marker == MarkerStyle.PLUS:
        _append_marker_line(
            svg,
            indent,
            css_class,
            command.x1 - radius,
            command.y1,
            command.x1 + radius,
            command.y1,
            color,
            max(1.0, command.marker_size * 0.24),
            command.opacity,
        )
        _append_marker_line(
            svg,
            indent,
            css_class,
            command.x1,
            command.y1 - radius,
            command.x1,
            command.y1 + radius,
            color,
            max(1.0, command.marker_size * 0.24),
            command.opacity,
        )
    elif marker == MarkerStyle.CROSS:
        _append_marker_line(
            svg,
            indent,
            css_class,
            command.x1 - radius,
            command.y1 - radius,
            command.x1 + radius,
            command.y1 + radius,
            color,
            max(1.0, command.marker_size * 0.24),
            command.opacity,
        )
        _append_marker_line(
            svg,
            indent,
            css_class,
            command.x1 - radius,
            command.y1 + radius,
            command.x1 + radius,
            command.y1 - radius,
            color,
            max(1.0, command.marker_size * 0.24),
            command.opacity,
        )
    else:
        svg += indent
        svg += '<polygon class="'
        svg += css_class
        svg += '" points="'
        # Scale the exact five-point-star unit geometry to the requested diameter.
        var star_scale = radius / 2.9
        _append_polygon_point(svg, command.x1, command.y1, 0.0, -2.9 * star_scale)
        svg += " "
        _append_polygon_point(
            svg,
            command.x1,
            command.y1,
            0.6465637775 * star_scale,
            -0.8899186938 * star_scale,
        )
        svg += " "
        _append_polygon_point(
            svg,
            command.x1,
            command.y1,
            2.758063897 * star_scale,
            -0.8961492837 * star_scale,
        )
        svg += " "
        _append_polygon_point(
            svg,
            command.x1,
            command.y1,
            1.046162168 * star_scale,
            0.3399186938 * star_scale,
        )
        svg += " "
        _append_polygon_point(
            svg,
            command.x1,
            command.y1,
            1.704577232 * star_scale,
            2.346149284 * star_scale,
        )
        svg += " "
        _append_polygon_point(svg, command.x1, command.y1, 0.0, 1.1 * star_scale)
        svg += " "
        _append_polygon_point(
            svg,
            command.x1,
            command.y1,
            -1.704577232 * star_scale,
            2.346149284 * star_scale,
        )
        svg += " "
        _append_polygon_point(
            svg,
            command.x1,
            command.y1,
            -1.046162168 * star_scale,
            0.3399186938 * star_scale,
        )
        svg += " "
        _append_polygon_point(
            svg,
            command.x1,
            command.y1,
            -2.758063897 * star_scale,
            -0.8961492837 * star_scale,
        )
        svg += " "
        _append_polygon_point(
            svg,
            command.x1,
            command.y1,
            -0.6465637775 * star_scale,
            -0.8899186938 * star_scale,
        )
        svg += '" fill="'
        svg += color
        svg += '"'
        _append_opacity(svg, command.opacity)
        svg += "/>\n"


def _encode_svg(plan: RenderPlan, options: TypstOptions) raises -> String:
    """Encode commands with fixed per-element attribute ordering."""
    var svg = String('<svg xmlns="http://www.w3.org/2000/svg" role="img"')
    var language_tag = plan.theme.typography().locale().language_tag()
    if language_tag.byte_length() > 0:
        svg += ' lang="'
        svg += _escape_xml(language_tag)
        svg += '" xml:lang="'
        svg += _escape_xml(language_tag)
        svg += '"'
    svg += ' width="'
    if plan.figure_config:
        _append_svg_number(svg, plan.figure_config.value().width())
        svg += "in"
    else:
        _append_svg_number(svg, plan.width)
    svg += '" height="'
    if plan.figure_config:
        _append_svg_number(svg, plan.figure_config.value().height())
        svg += "in"
    else:
        _append_svg_number(svg, plan.height)
    svg += '" viewBox="0 0 '
    _append_svg_number(svg, plan.width)
    svg += " "
    _append_svg_number(svg, plan.height)
    svg += '">\n'
    var accessible_title = plan.accessible_title.copy()
    if accessible_title.byte_length() == 0:
        accessible_title = String("Scientific plot")
        # Preserve the useful low-level RenderPlan behavior for callers that
        # construct title commands directly without accessibility metadata.
        for command in plan.commands:
            if command.kind == CommandKind.TITLE:
                accessible_title = command.text.copy()
                break
    svg += "  <title>"
    svg += _escape_xml(accessible_title)
    svg += "</title>\n"
    svg += "  <desc>Scientific plot rendered by Sen.</desc>\n"
    var background = plan.theme.background()
    var foreground = plan.theme.foreground()
    var grid = plan.theme.grid()
    var frame = plan.theme.frame()
    var legend_background = plan.theme.legend_background()
    var typography = plan.theme.typography()
    var family = typography.family()
    var cache = _TypstCache()
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
            # A nested SVG establishes a clipping viewport without a document-global
            # ID, so several inline Sen figures cannot collide with one another.
            svg += '  <svg class="sen-plot-clip" x="'
            _append_svg_number(svg, plan.plot_x)
            svg += '" y="'
            _append_svg_number(svg, plan.plot_y)
            svg += '" width="'
            _append_svg_number(svg, plan.plot_width)
            svg += '" height="'
            _append_svg_number(svg, plan.plot_height)
            svg += '" viewBox="'
            _append_svg_number(svg, plan.plot_x)
            svg += " "
            _append_svg_number(svg, plan.plot_y)
            svg += " "
            _append_svg_number(svg, plan.plot_width)
            svg += " "
            _append_svg_number(svg, plan.plot_height)
            svg += '" overflow="hidden">\n'
            series_group_open = True
        elif not is_series and series_group_open:
            svg += "  </svg>\n"
            series_group_open = False
        if command.kind._value == CommandKind.BACKGROUND._value:
            _append_rect(svg, command, background, "")
        elif command.kind._value == CommandKind.FRAME._value:
            _append_rect(svg, command, "none", frame)
        elif command.kind._value == CommandKind.LEGEND_BACKGROUND._value:
            _append_rect(svg, command, legend_background, frame)
        elif command.kind._value == CommandKind.RECTANGLE._value:
            _append_rect(svg, command, command.color, "", command.opacity)
        elif command.kind._value == CommandKind.LEGEND_RECTANGLE._value:
            _append_rect(svg, command, command.color, "", command.opacity)
        elif command.kind._value == CommandKind.LEGEND_AREA._value:
            _append_area_legend(svg, command)
        elif (
            command.kind._value == CommandKind.AXIS._value
            or command.kind._value == CommandKind.TICK._value
            or command.kind._value == CommandKind.GRID._value
        ):
            if command.kind._value == CommandKind.GRID._value:
                _append_line(svg, command, grid)
            else:
                _append_line(svg, command, foreground)
        elif (
            command.kind._value == CommandKind.X_LABEL._value
            or command.kind._value == CommandKind.Y_LABEL._value
            or command.kind._value == CommandKind.TITLE._value
            or command.kind._value == CommandKind.X_TITLE._value
            or command.kind._value == CommandKind.Y_TITLE._value
            or command.kind._value == CommandKind.LEGEND_TEXT._value
        ):
            if command.text_kind == TextKind.TYPST_MATH:
                _append_typst_text(
                    svg, command, index, plan, foreground, options, cache
                )
            else:
                _append_text(svg, command, family, foreground)
        elif command.kind._value == CommandKind.SERIES._value:
            _append_polyline(svg, command)
        elif command.kind._value == CommandKind.AREA._value:
            _append_area(svg, command)
        elif command.kind._value == CommandKind.LEGEND_LINE._value:
            _append_styled_line(svg, command)
        else:
            _append_marker(svg, command)
    if series_group_open:
        svg += "  </svg>\n"
    svg += "</svg>\n"
    return svg^


def _encode_svg(plan: RenderPlan) raises -> String:
    """Encode with default Typst options, used only by marked math text."""
    return _encode_svg(plan, TypstOptions())


def encode_svg(plan: RenderPlan) raises -> String:
    """Validate and encode an already-built renderer-neutral plan as SVG.

    Use this boundary when one ``RenderPlan`` is shared with several encoders or
    inspected before output.  The plan is not rebuilt and no file I/O occurs.
    Direct low-level mutation is checked before any SVG bytes are returned.
    """
    plan.validate()
    return _encode_svg(plan)


def encode_svg(plan: RenderPlan, options: TypstOptions) raises -> String:
    """Encode with explicit limits for any marked Typst mathematical text."""
    plan.validate()
    return _encode_svg(plan, options)


def render_svg(
    figure: Figure,
    width: Float64,
    height: Float64,
    margins: Margins,
) raises -> String:
    """Render ``figure`` to a complete deterministic SVG document.

    Empty figures are rejected. Automatic linear and logarithmic domains are
    padded safely and expanded when necessary so point-sized endpoint markers
    and strokes fit the measured plot viewport. Explicit axis limits remain
    exact and clip intentionally. Logarithmic rendering rejects non-positive
    data, limits, and ticks with axis and series context.

    CJK/emoji-aware fallback metrics drive adaptive margins, title wrapping,
    axis-label fitting, tick-label selection, and legend sizing. Every tick and
    grid mark is retained even when overlapping labels are omitted. Automatic
    palette slots are resolved in insertion order, and ``BEST`` legends score
    the four plot corners against rendered geometry. Series geometry is clipped
    to the exact plot-area viewport.
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
    width: Float64,
    height: Float64,
    margins: Margins,
    options: TypstOptions,
) raises -> String:
    """Render explicit geometry with options for marked Typst text."""
    return _encode_svg(build_render_plan(figure, width, height, margins), options)


def render_svg(
    figure: Figure,
    width: Float64,
    height: Float64,
) raises -> String:
    """Render legacy reference-pixel geometry with content-driven margins."""
    return _encode_svg(build_render_plan(figure, width, height))


def render_svg(
    figure: Figure,
    width: Float64,
    height: Float64,
    options: TypstOptions,
) raises -> String:
    """Render legacy geometry with options for marked Typst text."""
    return _encode_svg(build_render_plan(figure, width, height), options)


def render_svg(figure: Figure) raises -> String:
    """Render stored physical size with DPI-independent logical geometry."""
    return _encode_svg(build_render_plan(figure))


def render_svg(figure: Figure, options: TypstOptions) raises -> String:
    """Render stored geometry with options for marked Typst text."""
    return _encode_svg(build_render_plan(figure), options)


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
