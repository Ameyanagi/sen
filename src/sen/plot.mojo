"""A concise stateful front door for Sen's figure and SVG APIs."""

from .layout import Margins
from .series import AxisKind, Figure, LegendPosition, MissingPolicy, StepMode
from .style import SeriesStyle
from .svg import render_svg as _render_figure_svg, save_svg as _write_svg


struct Plot(Copyable):
    """Build and render one figure through a compact plotting vocabulary.

    ``Plot`` owns exactly one ``Figure`` and forwards every operation directly to
    it. Coordinate ingestion therefore allocates only the destination series
    buffers; the facade does not stage or copy input data. Validation, missing
    data, draw-order, scale, legend, and rendering semantics are exactly those of
    ``Figure`` and the SVG backend.
    """

    var _figure: Figure

    def __init__(out self):
        """Construct an empty plot with ``Figure`` defaults."""
        self._figure = Figure()

    def line(
        mut self,
        x: Span[Float64, ...],
        y: Span[Float64, ...],
        *,
        var label: String = String(),
        style: SeriesStyle = SeriesStyle(),
        missing: MissingPolicy = MissingPolicy.ERROR,
    ) raises:
        """Add a line using ``Figure.line`` validation and ownership semantics."""
        self._figure.line(x, y, label=label^, style=style, missing=missing)

    def scatter(
        mut self,
        x: Span[Float64, ...],
        y: Span[Float64, ...],
        *,
        var label: String = String(),
        style: SeriesStyle = SeriesStyle(),
        missing: MissingPolicy = MissingPolicy.ERROR,
    ) raises:
        """Add markers using ``Figure.scatter`` validation and ordering."""
        self._figure.scatter(x, y, label=label^, style=style, missing=missing)

    def area(
        mut self,
        x: Span[Float64, ...],
        y: Span[Float64, ...],
        *,
        baseline: Float64 = 0.0,
        var label: String = String(),
        style: SeriesStyle = SeriesStyle(),
        missing: MissingPolicy = MissingPolicy.ERROR,
    ) raises:
        """Fill one or more finite boundary segments to a constant baseline."""
        self._figure.area(
            x,
            y,
            baseline=baseline,
            label=label^,
            style=style,
            missing=missing,
        )

    def step(
        mut self,
        x: Span[Float64, ...],
        y: Span[Float64, ...],
        *,
        mode: StepMode = StepMode.PRE,
        var label: String = String(),
        style: SeriesStyle = SeriesStyle(),
    ) raises:
        """Add a PRE, POST, or MID step line as one logical series."""
        self._figure.step(x, y, mode=mode, label=label^, style=style)

    def stem(
        mut self,
        x: Span[Float64, ...],
        y: Span[Float64, ...],
        *,
        baseline: Float64 = 0.0,
        var label: String = String(),
        style: SeriesStyle = SeriesStyle(),
    ) raises:
        """Add vertical stems from a finite baseline."""
        self._figure.stem(x, y, baseline=baseline, label=label^, style=style)

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
        """Add symmetric vertical error bars."""
        self._figure.errorbar(
            x,
            y,
            y_error,
            cap_size=cap_size,
            label=label^,
            style=style,
        )

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
        """Add symmetric horizontal and vertical error bars."""
        self._figure.errorbar(
            x,
            y,
            x_error,
            y_error,
            cap_size=cap_size,
            label=label^,
            style=style,
        )

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
        """Add filled vertical numeric bars."""
        self._figure.bar(
            x,
            height,
            width=width,
            baseline=baseline,
            label=label^,
            style=style,
        )

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
        """Add filled vertical bars with categorical x tick labels."""
        self._figure.bar(
            categories,
            height,
            width=width,
            baseline=baseline,
            label=label^,
            style=style,
        )

    def histogram(
        mut self,
        data: Span[Float64, ...],
        *,
        bins: Int = 10,
        var label: String = String(),
        style: SeriesStyle = SeriesStyle(),
    ) raises:
        """Add an equal-width histogram over the observed finite range."""
        self._figure.histogram(data, bins=bins, label=label^, style=style)

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
        """Add an equal-width histogram over an explicit inclusive range."""
        self._figure.histogram(
            data,
            range_lo,
            range_hi,
            bins=bins,
            label=label^,
            style=style,
        )

    def title(mut self, var text: String):
        """Set the plot title exactly as supplied."""
        self._figure.set_title(text^)

    def xlabel(mut self, var text: String):
        """Set the x-axis label exactly as supplied."""
        self._figure.set_x_label(text^)

    def ylabel(mut self, var text: String):
        """Set the y-axis label exactly as supplied."""
        self._figure.set_y_label(text^)

    def grid(mut self, enabled: Bool = True):
        """Enable major gridlines by default, or disable them explicitly."""
        self._figure.set_grid(enabled)

    def xscale(mut self, scale: AxisKind):
        """Select the x-axis transform; log-domain checks occur at render time."""
        self._figure.set_x_scale(scale)

    def yscale(mut self, scale: AxisKind):
        """Select the y-axis transform; log-domain checks occur at render time."""
        self._figure.set_y_scale(scale)

    def xlim(mut self, lo: Float64, hi: Float64) raises:
        """Set finite ordered x limits using ``Figure`` validation."""
        self._figure.set_x_limits(lo, hi)

    def ylim(mut self, lo: Float64, hi: Float64) raises:
        """Set finite ordered y limits using ``Figure`` validation."""
        self._figure.set_y_limits(lo, hi)

    def legend(mut self, position: LegendPosition = LegendPosition.UPPER_RIGHT):
        """Show the legend at ``position`` or suppress it with ``NONE``."""
        self._figure.set_legend(position)

    def render_svg(
        self,
        width: Float64,
        height: Float64,
        margins: Margins,
    ) raises -> String:
        """Render with explicit geometry and margins."""
        return _render_figure_svg(self._figure, width, height, margins)

    def render_svg(
        self,
        width: Float64 = 640.0,
        height: Float64 = 480.0,
    ) raises -> String:
        """Render SVG with the backend's predictable default geometry."""
        return _render_figure_svg(self._figure, width, height)

    def save_svg(
        self,
        path: StringSlice,
        width: Float64 = 640.0,
        height: Float64 = 480.0,
    ) raises:
        """Render once with the requested size and replace ``path`` with its SVG."""
        var svg = _render_figure_svg(self._figure, width, height)
        _write_svg(path, svg)
