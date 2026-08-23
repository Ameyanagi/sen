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
from .style import (
    LineCap,
    LineJoin,
    LineStyle,
    MarkerStyle,
    SeriesStyle,
    _palette_color,
)
from .text import TextKind
from .text_metrics import text_height, text_width


def _points_to_logical(points: Float64) -> Float64:
    """Convert typographic points to Sen's DPI-independent 100-DPI space."""
    return points * 100.0 / 72.0


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
    kind: CommandKind,
    x: Float64,
    y: Float64,
    var text: String,
    font_size: Float64,
    text_kind: TextKind = TextKind.PLAIN,
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
        font_size=font_size,
        text_kind=text_kind,
    )


def _polyline_command(
    var points: List[PlanPoint],
    color: StringSlice,
    series_index: Int,
    line_width: Float64,
    line_style: LineStyle,
    opacity: Float64,
    line_cap: LineCap,
    line_join: LineJoin,
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
        6.0,
        opacity,
        line_cap,
        line_join,
    )


def _area_command(
    var points: List[PlanPoint],
    color: StringSlice,
    series_index: Int,
    line_width: Float64,
    line_style: LineStyle,
    opacity: Float64,
    line_cap: LineCap,
    line_join: LineJoin,
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
        6.0,
        opacity,
        line_cap,
        line_join,
    )


def _marker_command(
    kind: CommandKind,
    x: Float64,
    y: Float64,
    color: StringSlice,
    palette_slot: Int,
    series_index: Int,
    marker_style: MarkerStyle,
    marker_size: Float64,
    opacity: Float64,
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
        marker_size,
        opacity,
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
    opacity: Float64,
    line_cap: LineCap,
    line_join: LineJoin,
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
        6.0,
        opacity,
        line_cap,
        line_join,
    )


def _filled_rectangle_command(
    kind: CommandKind,
    x: Float64,
    y: Float64,
    width: Float64,
    height: Float64,
    color: StringSlice,
    series_index: Int,
    opacity: Float64 = 1.0,
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
        6.0,
        opacity,
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
    opacity: Float64,
    line_cap: LineCap,
    line_join: LineJoin,
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
        6.0,
        opacity,
        line_cap,
        line_join,
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


def _maximum_text_width(labels: List[String], font_size: Float64) raises -> Float64:
    var maximum = 0.0
    for index in range(len(labels)):
        maximum = max(maximum, text_width(labels[index], font_size))
    return maximum


def _role_text_height(font_size: Float64, kind: TextKind) raises -> Float64:
    """Return the bounded fallback line box reserved by semantic text roles."""
    if kind == TextKind.TYPST_MATH:
        # Typst integrals and scripts routinely exceed a plain 1.2-em line box.
        # Keep this in sync with the fixed fragment viewport in svg.mojo.
        return font_size * 2.4
    return text_height(font_size)


def _ellipsize_text(
    text: StringSlice, font_size: Float64, available_width: Float64
) raises -> String:
    """Fit one grapheme-safe line, adding one deterministic ellipsis if needed."""
    var ellipsis = String("…")
    var ellipsis_width = text_width(ellipsis, font_size)
    if ellipsis_width > available_width:
        return String()
    var graphemes = List[String]()
    var widths = List[Float64]()
    var full_width = 0.0
    for grapheme in text.graphemes():
        var stored = String(grapheme)
        var width = text_width(stored, font_size)
        graphemes.append(stored^)
        widths.append(width)
        full_width += width
    if full_width <= available_width:
        return String(text)
    var result = String()
    var used_width = 0.0
    for index in range(len(graphemes)):
        if used_width + widths[index] + ellipsis_width > available_width:
            break
        result += graphemes[index]
        used_width += widths[index]
    result += ellipsis
    return result^


def _join_graphemes(graphemes: List[String], start: Int, end: Int) -> String:
    var result = String()
    for index in range(start, end):
        result += graphemes[index]
    return String(result.strip())


struct _TitleLayout:
    """At most two deterministic title lines plus their shared point hierarchy."""

    var first: String
    var second: String
    var font_size: Float64

    def __init__(out self, var first: String, var second: String, font_size: Float64):
        self.first = first^
        self.second = second^
        self.font_size = font_size

    def line_count(self) -> Int:
        if self.second.byte_length() > 0:
            return 2
        if self.first.byte_length() > 0:
            return 1
        return 0


def _plain_title_layout(
    title: StringSlice,
    available_width: Float64,
    preferred_font_size: Float64,
    minimum_font_size: Float64,
) raises -> _TitleLayout:
    """Wrap a plain title into two readable lines, then ellipsize at 11 pt."""
    var graphemes = List[String]()
    var prefix_widths = List[Float64]()
    prefix_widths.append(0.0)
    for grapheme in title.graphemes():
        var stored = String(grapheme)
        var width = text_width(stored, preferred_font_size)
        graphemes.append(stored^)
        prefix_widths.append(prefix_widths[len(prefix_widths) - 1] + width)
    if prefix_widths[len(prefix_widths) - 1] <= available_width:
        return _TitleLayout(String(title), String(), preferred_font_size)
    if len(graphemes) < 2:
        return _TitleLayout(
            _ellipsize_text(title, minimum_font_size, available_width),
            String(),
            minimum_font_size,
        )

    # Prefer a boundary between words. A whitespace run is visited exactly once,
    # while prefix sums make every candidate measurement constant time.
    var best_first_end = 1
    var best_second_start = 1
    var best_extent = Float64.MAX_FINITE
    var found_word_break = False
    var index = 0
    while index < len(graphemes):
        if graphemes[index].strip().byte_length() > 0:
            index += 1
            continue
        var first_end = index
        while index < len(graphemes) and graphemes[index].strip().byte_length() == 0:
            index += 1
        if first_end == 0 or index == len(graphemes):
            continue
        var extent = max(
            prefix_widths[first_end],
            prefix_widths[len(graphemes)] - prefix_widths[index],
        )
        if extent < best_extent:
            found_word_break = True
            best_extent = extent
            best_first_end = first_end
            best_second_start = index
    if not found_word_break:
        for split in range(1, len(graphemes)):
            var extent = max(
                prefix_widths[split],
                prefix_widths[len(graphemes)] - prefix_widths[split],
            )
            if extent < best_extent:
                best_extent = extent
                best_first_end = split
                best_second_start = split
    var first = _join_graphemes(graphemes, 0, best_first_end)
    var second = _join_graphemes(graphemes, best_second_start, len(graphemes))
    var fitted_font_size = preferred_font_size
    if best_extent > available_width:
        fitted_font_size *= available_width / best_extent
    if fitted_font_size >= minimum_font_size:
        return _TitleLayout(first^, second^, fitted_font_size)

    # At the readability floor, maximize the complete first line and preserve
    # the remaining source in a single ellipsized second line.
    var preferred_width_limit = (
        available_width * preferred_font_size / minimum_font_size
    )
    var maximum_end = 0
    for candidate_end in range(1, len(graphemes) + 1):
        if prefix_widths[candidate_end] > preferred_width_limit:
            break
        maximum_end = candidate_end
    best_first_end = maximum_end
    best_second_start = maximum_end
    index = 0
    while index < maximum_end:
        if graphemes[index].strip().byte_length() > 0:
            index += 1
            continue
        var whitespace_start = index
        while index < len(graphemes) and graphemes[index].strip().byte_length() == 0:
            index += 1
        if whitespace_start > 0 and whitespace_start <= maximum_end:
            best_first_end = whitespace_start
            best_second_start = index
    first = _join_graphemes(graphemes, 0, best_first_end)
    second = _join_graphemes(graphemes, best_second_start, len(graphemes))
    second = _ellipsize_text(second, minimum_font_size, available_width)
    return _TitleLayout(first^, second^, minimum_font_size)


def _x_tick_label_visibility(
    ticks: List[Float64],
    labels: List[String],
    mapper: _AxisMapper,
    font_size: Float64,
    gap: Float64,
) raises -> List[Bool]:
    """Greedily select non-overlapping x labels from actual mapped bounds."""
    var visible = List[Bool](capacity=len(ticks))
    for _ in range(len(ticks)):
        visible.append(False)
    if len(ticks) == 0:
        return visible^
    visible[0] = True
    var previous_right = mapper.map(ticks[0]) + text_width(labels[0], font_size) / 2.0
    var last_left = Float64.MAX_FINITE
    if len(ticks) > 1:
        last_left = (
            mapper.map(ticks[len(ticks) - 1])
            - text_width(labels[len(labels) - 1], font_size) / 2.0
        )
    for index in range(1, len(ticks)):
        var center = mapper.map(ticks[index])
        var half_width = text_width(labels[index], font_size) / 2.0
        var left = center - half_width
        var right = center + half_width
        if left < previous_right + gap:
            continue
        if index < len(ticks) - 1 and right + gap > last_left:
            continue
        visible[index] = True
        previous_right = right
    return visible^


def _y_tick_label_visibility(
    ticks: List[Float64], mapper: _AxisMapper, label_height: Float64, gap: Float64
) raises -> List[Bool]:
    """Greedily select y labels top-to-bottom from actual mapped bounds."""
    var visible = List[Bool](capacity=len(ticks))
    for _ in range(len(ticks)):
        visible.append(False)
    if len(ticks) == 0:
        return visible^
    var previous_bottom = -Float64.MAX_FINITE
    for offset in range(len(ticks)):
        var index = len(ticks) - 1 - offset
        var center = mapper.map(ticks[index])
        var top = center - label_height / 2.0
        if top < previous_bottom + gap:
            continue
        visible[index] = True
        previous_bottom = center + label_height / 2.0
    return visible^


def _rectangles_overlap(
    ax: Float64,
    ay: Float64,
    aw: Float64,
    ah: Float64,
    bx: Float64,
    by: Float64,
    bw: Float64,
    bh: Float64,
) -> Bool:
    return ax < bx + bw and ax + aw > bx and ay < by + bh and ay + ah > by


def _point_in_polygon(points: List[PlanPoint], x: Float64, y: Float64) -> Bool:
    """Return whether a point lies inside a non-self-intersecting area polygon."""
    if len(points) < 3:
        return False
    var inside = False
    var previous_index = len(points) - 1
    for index in range(len(points)):
        ref point = points[index]
        ref previous = points[previous_index]
        if (point.y > y) != (previous.y > y):
            var crossing_x = (previous.x - point.x) * (y - point.y) / (
                previous.y - point.y
            ) + point.x
            if x < crossing_x:
                inside = not inside
        previous_index = index
    return inside


struct _LegendOverlapScores:
    """Overlap totals in deterministic upper-right, upper-left, lower order."""

    var upper_right: Int
    var upper_left: Int
    var lower_right: Int
    var lower_left: Int

    def __init__(out self):
        self.upper_right = 0
        self.upper_left = 0
        self.lower_right = 0
        self.lower_left = 0


def _add_rectangle_overlap_scores(
    mut scores: _LegendOverlapScores,
    geometry_x: Float64,
    geometry_y: Float64,
    geometry_width: Float64,
    geometry_height: Float64,
    left_x: Float64,
    right_x: Float64,
    top_y: Float64,
    bottom_y: Float64,
    legend_width: Float64,
    legend_height: Float64,
    weight: Int,
):
    if _rectangles_overlap(
        geometry_x,
        geometry_y,
        geometry_width,
        geometry_height,
        right_x,
        top_y,
        legend_width,
        legend_height,
    ):
        scores.upper_right += weight
    if _rectangles_overlap(
        geometry_x,
        geometry_y,
        geometry_width,
        geometry_height,
        left_x,
        top_y,
        legend_width,
        legend_height,
    ):
        scores.upper_left += weight
    if _rectangles_overlap(
        geometry_x,
        geometry_y,
        geometry_width,
        geometry_height,
        right_x,
        bottom_y,
        legend_width,
        legend_height,
    ):
        scores.lower_right += weight
    if _rectangles_overlap(
        geometry_x,
        geometry_y,
        geometry_width,
        geometry_height,
        left_x,
        bottom_y,
        legend_width,
        legend_height,
    ):
        scores.lower_left += weight


def _add_point_overlap_scores(
    mut scores: _LegendOverlapScores,
    point_x: Float64,
    point_y: Float64,
    left_x: Float64,
    right_x: Float64,
    top_y: Float64,
    bottom_y: Float64,
    legend_width: Float64,
    legend_height: Float64,
    weight: Int,
):
    var in_right = point_x >= right_x and point_x <= right_x + legend_width
    var in_left = point_x >= left_x and point_x <= left_x + legend_width
    var in_top = point_y >= top_y and point_y <= top_y + legend_height
    var in_bottom = point_y >= bottom_y and point_y <= bottom_y + legend_height
    if in_right and in_top:
        scores.upper_right += weight
    if in_left and in_top:
        scores.upper_left += weight
    if in_right and in_bottom:
        scores.lower_right += weight
    if in_left and in_bottom:
        scores.lower_left += weight


def _area_overlaps_legend_interior(
    points: List[PlanPoint], x: Float64, y: Float64, width: Float64, height: Float64
) -> Bool:
    return (
        _point_in_polygon(points, x, y)
        or _point_in_polygon(points, x + width, y)
        or _point_in_polygon(points, x, y + height)
        or _point_in_polygon(points, x + width, y + height)
        or _point_in_polygon(points, x + width / 2.0, y + height / 2.0)
    )


def _legend_overlap_scores(
    commands: List[DrawCommand],
    left_x: Float64,
    right_x: Float64,
    top_y: Float64,
    bottom_y: Float64,
    width: Float64,
    height: Float64,
) -> _LegendOverlapScores:
    """Score all four prospective legend rectangles in one command traversal."""
    var scores = _LegendOverlapScores()
    for command_index in range(len(commands)):
        ref command = commands[command_index]
        if command.kind == CommandKind.MARKER:
            var radius = command.marker_size / 2.0
            _add_rectangle_overlap_scores(
                scores,
                command.x1 - radius,
                command.y1 - radius,
                2.0 * radius,
                2.0 * radius,
                left_x,
                right_x,
                top_y,
                bottom_y,
                width,
                height,
                4,
            )
        elif command.kind == CommandKind.RECTANGLE:
            _add_rectangle_overlap_scores(
                scores,
                command.x1,
                command.y1,
                command.x2,
                command.y2,
                left_x,
                right_x,
                top_y,
                bottom_y,
                width,
                height,
                5,
            )
        elif command.kind == CommandKind.SERIES or command.kind == CommandKind.AREA:
            if command.kind == CommandKind.AREA:
                # Vertices and boundaries do not reveal a legend wholly inside a
                # broad filled region, so sample its corners and center too.
                if _area_overlaps_legend_interior(
                    command.points, right_x, top_y, width, height
                ):
                    scores.upper_right += 8
                if _area_overlaps_legend_interior(
                    command.points, left_x, top_y, width, height
                ):
                    scores.upper_left += 8
                if _area_overlaps_legend_interior(
                    command.points, right_x, bottom_y, width, height
                ):
                    scores.lower_right += 8
                if _area_overlaps_legend_interior(
                    command.points, left_x, bottom_y, width, height
                ):
                    scores.lower_left += 8
            for point_index in range(len(command.points)):
                ref point = command.points[point_index]
                _add_point_overlap_scores(
                    scores,
                    point.x,
                    point.y,
                    left_x,
                    right_x,
                    top_y,
                    bottom_y,
                    width,
                    height,
                    3,
                )
            for point_index in range(1, len(command.points)):
                ref first = command.points[point_index - 1]
                ref second = command.points[point_index]
                var stroke_radius = command.line_width / 2.0
                var segment_x = min(first.x, second.x) - stroke_radius
                var segment_y = min(first.y, second.y) - stroke_radius
                var segment_width = abs(second.x - first.x) + 2.0 * stroke_radius
                var segment_height = abs(second.y - first.y) + 2.0 * stroke_radius
                _add_rectangle_overlap_scores(
                    scores,
                    segment_x,
                    segment_y,
                    max(segment_width, 0.001),
                    max(segment_height, 0.001),
                    left_x,
                    right_x,
                    top_y,
                    bottom_y,
                    width,
                    height,
                    1,
                )
    return scores^


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


def _line_half_extent(style: SeriesStyle) -> Float64:
    """Conservatively bound one stroked path around every data-space vertex."""
    var half_stroke = _points_to_logical(style.line_width()) / 2.0
    var extent = half_stroke
    if style.line_cap() == LineCap.SQUARE:
        # A square cap extends by half a stroke both along and perpendicular to
        # its segment; either axis is therefore bounded by sqrt(2) times half.
        extent = max(extent, half_stroke * 1.4142135623730951)
    if style.line_join() == LineJoin.MITER:
        # No stroke-miterlimit is encoded, so SVG's default limit of 4 applies.
        extent = max(extent, half_stroke * 4.0)
    return extent


def _marker_half_extent(style: SeriesStyle) -> Float64:
    """Conservatively bound marker geometry in either device-space axis."""
    var diameter = _points_to_logical(style.marker_size())
    var radius = diameter / 2.0
    var marker_stroke = max(1.0, diameter * 0.24)
    if style.marker_style() == MarkerStyle.CROSS:
        # Both diagonal strokes reach radius in x and y. Their butt-ended stroke
        # adds a perpendicular projection; half its full width is conservative.
        return radius + marker_stroke / 2.0
    if style.marker_style() == MarkerStyle.PLUS:
        return max(radius, marker_stroke / 2.0)
    return radius


struct _DomainPadding:
    """One-axis geometry-padding accumulator updated in a shared series pass."""

    var original_lo: Float64
    var original_hi: Float64
    var center: Float64
    var half_span: Float64
    var expanded_half_span: Float64
    var plot_length: Float64
    var kind: AxisKind
    var enabled: Bool
    var impossible: Bool

    def __init__(
        out self,
        domain: Tuple[Float64, Float64],
        plot_length: Float64,
        kind: AxisKind,
        enabled: Bool,
    ):
        self.original_lo = domain[0]
        self.original_hi = domain[1]
        var coordinate_lo = domain[0]
        var coordinate_hi = domain[1]
        if kind == AxisKind.LOG10:
            coordinate_lo = log10(coordinate_lo)
            coordinate_hi = log10(coordinate_hi)
        self.center = coordinate_lo * 0.5 + coordinate_hi * 0.5
        self.half_span = coordinate_hi * 0.5 - coordinate_lo * 0.5
        self.expanded_half_span = self.half_span
        self.plot_length = plot_length
        self.kind = kind
        self.enabled = enabled
        self.impossible = False

    def include(mut self, lo: Float64, hi: Float64, half_extent: Float64):
        if not self.enabled:
            return
        if not isfinite(half_extent) or half_extent > self.plot_length / 2.0:
            self.impossible = True
            return
        var coordinate_lo = lo
        var coordinate_hi = hi
        if self.kind == AxisKind.LOG10:
            coordinate_lo = log10(coordinate_lo)
            coordinate_hi = log10(coordinate_hi)
        if half_extent == self.plot_length / 2.0:
            if coordinate_lo != self.center or coordinate_hi != self.center:
                self.impossible = True
            return
        var interior_fraction = 1.0 - 2.0 * half_extent / self.plot_length
        self.expanded_half_span = max(
            self.expanded_half_span,
            max(self.center - coordinate_lo, coordinate_hi - self.center)
            / interior_fraction,
        )

    def finish(self, axis_name: StringSlice) raises -> Tuple[Float64, Float64]:
        if not self.enabled:
            return (self.original_lo, self.original_hi)
        if self.impossible:
            raise Error(
                "series geometry cannot fit within the ",
                axis_name,
                " plot span; reduce marker size or line width, increase figure ",
                "width" if axis_name == "x" else "height",
                ", or set explicit limits to clip intentionally",
            )
        if self.expanded_half_span == self.half_span:
            return (self.original_lo, self.original_hi)
        # Guard log10/pow round-trips and affine endpoint rounding by a few ulps.
        var expanded_half_span = self.expanded_half_span * (1.0 + 1.0e-8)
        var expanded_lo = self.center - expanded_half_span
        var expanded_hi = self.center + expanded_half_span
        if self.kind == AxisKind.LOG10:
            expanded_lo = pow(10.0, expanded_lo)
            expanded_hi = pow(10.0, expanded_hi)
        if (
            not isfinite(expanded_lo)
            or not isfinite(expanded_hi)
            or expanded_lo >= expanded_hi
            or (self.kind == AxisKind.LOG10 and expanded_lo <= 0.0)
        ):
            raise Error(
                "automatic ",
                axis_name,
                " domain cannot represent the padding required by marker size or ",
                "line width; reduce the style size or use explicit limits to clip ",
                "intentionally",
            )
        return (expanded_lo, expanded_hi)


def _expand_automatic_domains_for_geometry(
    figure: Figure,
    x_domain: Tuple[Float64, Float64],
    y_domain: Tuple[Float64, Float64],
    plot_width: Float64,
    plot_height: Float64,
    x_kind: AxisKind,
    y_kind: AxisKind,
    expand_x: Bool,
    expand_y: Bool,
) raises -> Tuple[Tuple[Float64, Float64], Tuple[Float64, Float64]]:
    """Accumulate both axis constraints with exactly one per-series bounds pass."""
    var x_padding = _DomainPadding(x_domain, plot_width, x_kind, expand_x)
    var y_padding = _DomainPadding(y_domain, plot_height, y_kind, expand_y)
    for order_index in range(figure._series_count()):
        if figure._series_is_rectangle(order_index):
            continue
        var series_index = figure._series_index(order_index)
        var style = figure._series_style(order_index)
        var half_extent: Float64
        var bounds: DataBounds
        if figure._series_is_line(order_index):
            ref line = figure.line(series_index)
            if line.is_empty():
                continue
            half_extent = _line_half_extent(style)
            bounds = line.bounds()
        elif figure._series_is_area(order_index):
            ref filled_area = figure.area(series_index)
            if filled_area.is_empty():
                continue
            half_extent = _line_half_extent(style)
            bounds = filled_area.bounds()
        else:
            ref scatter = figure.scatter(series_index)
            if scatter.is_empty():
                continue
            half_extent = _marker_half_extent(style)
            bounds = scatter.bounds()
        x_padding.include(bounds.x_min(), bounds.x_max(), half_extent)
        y_padding.include(bounds.y_min(), bounds.y_max(), half_extent)
    # Preserve deterministic x-before-y error ordering after the shared scan.
    var expanded_x = x_padding.finish("x")
    var expanded_y = y_padding.finish("y")
    return (expanded_x, expanded_y)


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
    var theme = figure.theme()
    var typography = theme.typography()
    var title_font_size = _points_to_logical(typography.title_size())
    var axis_font_size = _points_to_logical(typography.axis_size())
    var tick_font_size = _points_to_logical(typography.tick_size())
    var legend_font_size = _points_to_logical(typography.legend_size())
    var title = figure.title().copy()
    var x_label = figure.x_label().copy()
    var y_label = figure.y_label().copy()
    var data_bounds = figure.bounds()
    var x_limits = figure.x_limits()
    var y_limits = figure.y_limits()
    var x_axis_kind = figure.x_scale()
    var y_axis_kind = figure.y_scale()
    # The public setters establish this invariant atomically. Recheck it here
    # before filtering or emitting commands so corrupted internal storage can
    # never produce a partially meaningful plan.
    if figure.has_explicit_x_ticks():
        for index in range(1, figure.x_tick_count()):
            if figure.x_tick_position(index) <= figure.x_tick_position(index - 1):
                raise Error(
                    "x tick positions must be strictly increasing; index ",
                    index,
                    " has value ",
                    _diagnostic_value(figure.x_tick_position(index)),
                    ", which is not greater than previous value ",
                    _diagnostic_value(figure.x_tick_position(index - 1)),
                    "; sort positions and remove duplicates",
                )
    if figure.has_explicit_y_ticks():
        for index in range(1, figure.y_tick_count()):
            if figure.y_tick_position(index) <= figure.y_tick_position(index - 1):
                raise Error(
                    "y tick positions must be strictly increasing; index ",
                    index,
                    " has value ",
                    _diagnostic_value(figure.y_tick_position(index)),
                    ", which is not greater than previous value ",
                    _diagnostic_value(figure.y_tick_position(index - 1)),
                    "; sort positions and remove duplicates",
                )
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
        margin=0.08,
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

    # Resolve label strings once, then measure their grapheme-aware fallback
    # extents before finalizing the plot rectangle. This keeps CJK, combining
    # sequences, and emoji from inheriting the former codepoint-count layout.
    var x_tick_labels = List[String](capacity=len(x_ticks))
    for tick_index in range(len(x_ticks)):
        if figure.has_explicit_x_ticks():
            x_tick_labels.append(explicit_x_tick_labels[tick_index].copy())
        else:
            x_tick_labels.append(_tick_label(x_ticks[tick_index], x_step))
    var y_tick_labels = List[String](capacity=len(y_ticks))
    for tick_index in range(len(y_ticks)):
        if figure.has_explicit_y_ticks():
            y_tick_labels.append(explicit_y_tick_labels[tick_index].copy())
        else:
            y_tick_labels.append(_tick_label(y_ticks[tick_index], y_step))

    var edge_buffer = 8.0
    var tick_length = _points_to_logical(4.0)
    var tick_padding = _points_to_logical(3.5)
    var tick_label_height = text_height(tick_font_size)
    var x_axis_label_height = _role_text_height(axis_font_size, figure.x_label_kind())
    var y_axis_label_height = _role_text_height(axis_font_size, figure.y_label_kind())
    var measured_left = edge_buffer + tick_length + tick_padding
    measured_left += _maximum_text_width(y_tick_labels, tick_font_size)
    if y_label.byte_length() > 0:
        measured_left += y_axis_label_height + _points_to_logical(4.0)
    var measured_bottom = edge_buffer + tick_length + tick_padding
    measured_bottom += tick_label_height
    if x_label.byte_length() > 0:
        measured_bottom += x_axis_label_height + _points_to_logical(4.0)
    var measured_right = edge_buffer
    if len(x_tick_labels) > 0:
        measured_left = max(
            measured_left,
            edge_buffer + text_width(x_tick_labels[0], tick_font_size) / 2.0,
        )
        measured_right = max(
            measured_right,
            edge_buffer
            + text_width(x_tick_labels[len(x_tick_labels) - 1], tick_font_size) / 2.0,
        )
    var effective_left = max(margins.left(), measured_left)
    var effective_right = max(margins.right(), measured_right)
    var available_title_width = max(1.0, width - effective_left - effective_right)
    var minimum_title_font_size = _points_to_logical(11.0)
    var title_layout = _TitleLayout(String(), String(), title_font_size)
    if title.byte_length() > 0:
        if figure.title_kind() == TextKind.PLAIN:
            title_layout = _plain_title_layout(
                title,
                available_title_width,
                title_font_size,
                minimum_title_font_size,
            )
        else:
            title_layout = _TitleLayout(title.copy(), String(), title_font_size)
    title_font_size = title_layout.font_size
    var title_height = _role_text_height(title_font_size, figure.title_kind())
    var measured_top = edge_buffer
    if title_layout.line_count() > 0:
        measured_top += title_height * Float64(title_layout.line_count())
        measured_top += _points_to_logical(4.0)
    var effective_margins = Margins(
        effective_left,
        effective_right,
        max(margins.top(), measured_top),
        max(margins.bottom(), measured_bottom),
    )
    var area = plot_area(width, height, effective_margins)
    var expand_x_domain = not x_limits
    var expand_y_domain = not y_limits
    if not x_limits or not y_limits:
        var expanded_domains = _expand_automatic_domains_for_geometry(
            figure,
            x_domain,
            y_domain,
            area.width(),
            area.height(),
            x_axis_kind,
            y_axis_kind,
            expand_x_domain,
            expand_y_domain,
        )
        x_domain = expanded_domains[0]
        y_domain = expanded_domains[1]
    # Construct each axis mapper exactly once after content-driven layout.
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
    var x_label_visibility = _x_tick_label_visibility(
        x_ticks,
        x_tick_labels,
        x_mapper,
        tick_font_size,
        _points_to_logical(4.0),
    )
    var y_label_visibility = _y_tick_label_visibility(
        y_ticks,
        y_mapper,
        tick_label_height,
        _points_to_logical(2.0),
    )
    if x_label.byte_length() > 0 and figure.x_label_kind() == TextKind.PLAIN:
        x_label = _ellipsize_text(x_label, axis_font_size, area.width())
    if y_label.byte_length() > 0 and figure.y_label_kind() == TextKind.PLAIN:
        y_label = _ellipsize_text(y_label, axis_font_size, area.height())

    # Size command-heavy plans before appending any command. Series topology and
    # tick lists already expose every data-dependent command count; the legend
    # allowance deliberately assumes that every series is labeled so this sizing
    # pass does not duplicate legend text measurement. Small plans retain List's
    # default growth path because reserving them did not improve their profile.
    var command_capacity = 4 + 2 * (len(x_ticks) + len(y_ticks))
    if figure.grid_enabled():
        command_capacity += len(x_ticks) + len(y_ticks)
    command_capacity += title_layout.line_count()
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
        commands.append(
            _shape_command(CommandKind.TICK, x, bottom, x, bottom + tick_length)
        )
        if not x_label_visibility[tick_index]:
            continue
        commands.append(
            _text_command(
                CommandKind.X_LABEL,
                x,
                bottom + tick_length + tick_padding + tick_font_size * 0.8,
                x_tick_labels[tick_index].copy(),
                tick_font_size,
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
                area.x() - tick_length,
                y,
                area.x(),
                y,
            )
        )
        if not y_label_visibility[tick_index]:
            continue
        commands.append(
            _text_command(
                CommandKind.Y_LABEL,
                area.x() - tick_length - tick_padding,
                y + tick_font_size * 0.32,
                y_tick_labels[tick_index].copy(),
                tick_font_size,
            )
        )

    if title_layout.line_count() > 0:
        var title_gap = _points_to_logical(4.0)
        var last_title_y = area.y() - title_gap
        if figure.title_kind() == TextKind.TYPST_MATH:
            # The matching 2.4-em viewport extends 0.9 em below this anchor.
            last_title_y -= title_font_size * 0.9
        if title_layout.second.byte_length() > 0:
            commands.append(
                _text_command(
                    CommandKind.TITLE,
                    area.x() + area.width() / 2.0,
                    last_title_y - title_height,
                    title_layout.first.copy(),
                    title_font_size,
                    figure.title_kind(),
                )
            )
            commands.append(
                _text_command(
                    CommandKind.TITLE,
                    area.x() + area.width() / 2.0,
                    last_title_y,
                    title_layout.second.copy(),
                    title_font_size,
                    figure.title_kind(),
                )
            )
        else:
            commands.append(
                _text_command(
                    CommandKind.TITLE,
                    area.x() + area.width() / 2.0,
                    last_title_y,
                    title_layout.first.copy(),
                    title_font_size,
                    figure.title_kind(),
                )
            )
    if x_label.byte_length() > 0:
        var x_title_y = height - edge_buffer - axis_font_size * 0.15
        if figure.x_label_kind() == TextKind.TYPST_MATH:
            x_title_y = height - edge_buffer - axis_font_size * 0.9
        commands.append(
            _text_command(
                CommandKind.X_TITLE,
                area.x() + area.width() / 2.0,
                x_title_y,
                x_label^,
                axis_font_size,
                figure.x_label_kind(),
            )
        )
    if y_label.byte_length() > 0:
        var y_title_x = edge_buffer + axis_font_size * 0.5
        if figure.y_label_kind() == TextKind.TYPST_MATH:
            y_title_x = edge_buffer + axis_font_size * 0.9
        commands.append(
            _text_command(
                CommandKind.Y_TITLE,
                y_title_x,
                area.y() + area.height() / 2.0,
                y_label^,
                axis_font_size,
                figure.y_label_kind(),
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
                        _points_to_logical(style.line_width()),
                        style.line_style(),
                        style.opacity(),
                        style.line_cap(),
                        style.line_join(),
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
                        _points_to_logical(style.line_width()),
                        style.line_style(),
                        style.opacity(),
                        style.line_cap(),
                        style.line_join(),
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
                        style.opacity(),
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
                        _points_to_logical(style.marker_size()),
                        style.opacity(),
                    )
                )

    var legend_position = figure.legend_position()
    if legend_position != LegendPosition.NONE:
        var labeled_count = 0
        var longest_label_width = 0.0
        var legend_padding = _points_to_logical(5.0)
        var legend_gap = _points_to_logical(4.0)
        var legend_handle = _points_to_logical(12.0)
        var legend_glyph_width = legend_handle
        var legend_row_height = max(
            text_height(legend_font_size), _points_to_logical(10.0)
        )
        for order_index in range(figure._series_count()):
            var label = figure._series_label(order_index)
            if label.byte_length() == 0:
                continue
            labeled_count += 1
            longest_label_width = max(
                longest_label_width, text_width(label, legend_font_size)
            )
            var style = figure._series_style(order_index)
            if figure._series_is_line(order_index):
                var stroke_width = _points_to_logical(style.line_width())
                legend_row_height = max(legend_row_height, stroke_width)
                if stroke_width > legend_handle:
                    legend_glyph_width = max(
                        legend_glyph_width, legend_handle + stroke_width
                    )
            elif figure._series_is_area(order_index):
                var stroke_width = _points_to_logical(style.line_width())
                legend_row_height = max(legend_row_height, 2.5 * stroke_width)
                if stroke_width > _points_to_logical(4.0):
                    legend_glyph_width = max(
                        legend_glyph_width, legend_handle - 4.0 + stroke_width
                    )
            elif not figure._series_is_rectangle(order_index):
                var marker_diameter = _points_to_logical(style.marker_size())
                legend_glyph_width = max(legend_glyph_width, marker_diameter)
                legend_row_height = max(legend_row_height, marker_diameter)
        if labeled_count > 0:
            var legend_width = (
                2.0 * legend_padding
                + legend_glyph_width
                + legend_gap
                + longest_label_width
            )
            var legend_height = 2.0 * legend_padding + legend_row_height * Float64(
                labeled_count
            )
            if legend_width + 2.0 * edge_buffer > area.width():
                raise Error(
                    "legend does not fit within the plot area; increase figure width "
                    "or shorten labels"
                )
            if legend_height + 2.0 * edge_buffer > area.height():
                raise Error(
                    "legend does not fit within the plot area; increase figure height "
                    "or reduce labeled series"
                )
            var legend_x = area.x() + 8.0
            var legend_y = area.y() + 8.0
            if legend_position == LegendPosition.BEST:
                var right_x = area.x() + area.width() - 8.0 - legend_width
                var bottom_y = area.y() + area.height() - 8.0 - legend_height
                # Deterministic ties prefer upper-right, then upper-left,
                # lower-right, and lower-left.
                var scores = _legend_overlap_scores(
                    commands,
                    area.x() + 8.0,
                    right_x,
                    legend_y,
                    bottom_y,
                    legend_width,
                    legend_height,
                )
                var best_score = scores.upper_right
                legend_x = right_x
                if scores.upper_left < best_score:
                    best_score = scores.upper_left
                    legend_x = area.x() + 8.0
                if scores.lower_right < best_score:
                    best_score = scores.lower_right
                    legend_x = right_x
                    legend_y = bottom_y
                if scores.lower_left < best_score:
                    legend_x = area.x() + 8.0
                    legend_y = bottom_y
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
                var center_y = (
                    legend_y
                    + legend_padding
                    + legend_row_height * (Float64(row_index) + 0.5)
                )
                var glyph_x = legend_x + legend_padding
                var glyph_offset = (legend_glyph_width - legend_handle) / 2.0
                var style = figure._series_style(order_index)
                var palette_slot = resolved_slots[order_index]
                ref color = resolved_colors[order_index]
                if figure._series_is_line(order_index):
                    commands.append(
                        _styled_line_command(
                            CommandKind.LEGEND_LINE,
                            glyph_x + glyph_offset,
                            center_y,
                            glyph_x + glyph_offset + legend_handle,
                            center_y,
                            color,
                            _points_to_logical(style.line_width()),
                            style.line_style(),
                            style.opacity(),
                            style.line_cap(),
                            style.line_join(),
                        )
                    )
                elif figure._series_is_area(order_index):
                    commands.append(
                        _area_legend_command(
                            glyph_x + glyph_offset + 2.0,
                            center_y - legend_row_height * 0.3,
                            legend_handle - 4.0,
                            legend_row_height * 0.6,
                            color,
                            _points_to_logical(style.line_width()),
                            style.line_style(),
                            style.opacity(),
                            style.line_cap(),
                            style.line_join(),
                        )
                    )
                elif figure._series_is_rectangle(order_index):
                    commands.append(
                        _filled_rectangle_command(
                            CommandKind.LEGEND_RECTANGLE,
                            glyph_x + glyph_offset + 2.0,
                            center_y - legend_row_height * 0.3,
                            legend_handle - 4.0,
                            legend_row_height * 0.6,
                            color,
                            -1,
                            style.opacity(),
                        )
                    )
                else:
                    commands.append(
                        _marker_command(
                            CommandKind.LEGEND_MARKER,
                            glyph_x + legend_glyph_width / 2.0,
                            center_y,
                            color,
                            palette_slot,
                            -1,
                            style.marker_style(),
                            _points_to_logical(style.marker_size()),
                            style.opacity(),
                        )
                    )
                commands.append(
                    _text_command(
                        CommandKind.LEGEND_TEXT,
                        glyph_x + legend_glyph_width + legend_gap,
                        center_y + legend_font_size * 0.32,
                        label^,
                        legend_font_size,
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
        theme,
        accessible_title=figure.title().copy(),
    )


def build_render_plan(
    figure: Figure, width: Float64, height: Float64
) raises -> RenderPlan:
    """Lower legacy reference-pixel geometry with content-driven minimum margins."""
    return build_render_plan(
        figure,
        width,
        height,
        Margins(12.0, 12.0, 12.0, 12.0),
    )


def build_render_plan(figure: Figure) raises -> RenderPlan:
    """Lower using stored physical size in DPI-independent logical coordinates."""
    var config = figure.config()
    var plan = build_render_plan(
        figure,
        config.logical_width(),
        config.logical_height(),
        Margins(12.0, 12.0, 12.0, 12.0),
    )
    plan.figure_config = config
    plan.validate()
    return plan^
