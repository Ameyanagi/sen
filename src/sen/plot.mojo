"""A concise stateful front door for Sen's figure and SVG APIs."""

from .layout import Margins
from .lowering import build_render_plan as _build_figure_render_plan
from .render_plan import RenderPlan
from .series import AxisKind, Figure, LegendPosition, MissingPolicy, StepMode
from .style import SeriesStyle
from .svg import render_svg as _render_figure_svg, write_svg as _write_svg


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

    def __init__(out self, var figure: Figure):
        """Take ownership of an existing renderer-neutral figure."""
        self._figure = figure^

    def figure(self) -> ref[self._figure] Figure:
        """Borrow the underlying figure for renderer-independent inspection."""
        return self._figure

    def into_figure(var self) -> Figure:
        """Consume this plot and move out its underlying figure."""
        var figure = Figure()
        swap(figure, self._figure)
        return figure^

    def validate(self) raises:
        """Validate every invariant stored by the underlying figure."""
        self._figure.validate()

    def line(
        mut self,
        x: Span[Float64, ImmutAnyOrigin],
        y: Span[Float64, ImmutAnyOrigin],
        *,
        var label: String = String(),
        style: SeriesStyle = SeriesStyle(),
        missing: MissingPolicy = MissingPolicy.ERROR,
    ) raises:
        """Add a line using ``Figure.line`` validation and ownership semantics."""
        self._figure.line(x, y, label=label^, style=style, missing=missing)

    def with_line(
        var self,
        x: Span[Float64, ImmutAnyOrigin],
        y: Span[Float64, ImmutAnyOrigin],
        *,
        var label: String = String(),
        style: SeriesStyle = SeriesStyle(),
        missing: MissingPolicy = MissingPolicy.ERROR,
    ) raises -> Self:
        """Consume this plot, add a line, and return the updated plot."""
        self.line(x, y, label=label^, style=style, missing=missing)
        return self^

    def scatter(
        mut self,
        x: Span[Float64, ImmutAnyOrigin],
        y: Span[Float64, ImmutAnyOrigin],
        *,
        var label: String = String(),
        style: SeriesStyle = SeriesStyle(),
        missing: MissingPolicy = MissingPolicy.ERROR,
    ) raises:
        """Add markers using ``Figure.scatter`` validation and ordering."""
        self._figure.scatter(x, y, label=label^, style=style, missing=missing)

    def with_scatter(
        var self,
        x: Span[Float64, ImmutAnyOrigin],
        y: Span[Float64, ImmutAnyOrigin],
        *,
        var label: String = String(),
        style: SeriesStyle = SeriesStyle(),
        missing: MissingPolicy = MissingPolicy.ERROR,
    ) raises -> Self:
        """Consume this plot, add markers, and return the updated plot."""
        self.scatter(x, y, label=label^, style=style, missing=missing)
        return self^

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
        """Fill one or more finite boundary segments to a constant baseline."""
        self._figure.area(
            x,
            y,
            baseline=baseline,
            label=label^,
            style=style,
            missing=missing,
        )

    def with_area(
        var self,
        x: Span[Float64, ImmutAnyOrigin],
        y: Span[Float64, ImmutAnyOrigin],
        *,
        baseline: Float64 = 0.0,
        var label: String = String(),
        style: SeriesStyle = SeriesStyle(),
        missing: MissingPolicy = MissingPolicy.ERROR,
    ) raises -> Self:
        """Consume this plot, add a filled area, and return the updated plot."""
        self.area(
            x,
            y,
            baseline=baseline,
            label=label^,
            style=style,
            missing=missing,
        )
        return self^

    def step(
        mut self,
        x: Span[Float64, ImmutAnyOrigin],
        y: Span[Float64, ImmutAnyOrigin],
        *,
        mode: StepMode = StepMode.PRE,
        var label: String = String(),
        style: SeriesStyle = SeriesStyle(),
    ) raises:
        """Add a PRE, POST, or MID step line as one logical series."""
        self._figure.step(x, y, mode=mode, label=label^, style=style)

    def with_step(
        var self,
        x: Span[Float64, ImmutAnyOrigin],
        y: Span[Float64, ImmutAnyOrigin],
        *,
        mode: StepMode = StepMode.PRE,
        var label: String = String(),
        style: SeriesStyle = SeriesStyle(),
    ) raises -> Self:
        """Consume this plot, add a step line, and return the updated plot."""
        self.step(x, y, mode=mode, label=label^, style=style)
        return self^

    def stem(
        mut self,
        x: Span[Float64, ImmutAnyOrigin],
        y: Span[Float64, ImmutAnyOrigin],
        *,
        baseline: Float64 = 0.0,
        var label: String = String(),
        style: SeriesStyle = SeriesStyle(),
    ) raises:
        """Add vertical stems from a finite baseline."""
        self._figure.stem(x, y, baseline=baseline, label=label^, style=style)

    def with_stem(
        var self,
        x: Span[Float64, ImmutAnyOrigin],
        y: Span[Float64, ImmutAnyOrigin],
        *,
        baseline: Float64 = 0.0,
        var label: String = String(),
        style: SeriesStyle = SeriesStyle(),
    ) raises -> Self:
        """Consume this plot, add stems, and return the updated plot."""
        self.stem(x, y, baseline=baseline, label=label^, style=style)
        return self^

    def errorbar(
        mut self,
        x: Span[Float64, ImmutAnyOrigin],
        y: Span[Float64, ImmutAnyOrigin],
        y_error: Span[Float64, ImmutAnyOrigin],
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

    def with_errorbar(
        var self,
        x: Span[Float64, ImmutAnyOrigin],
        y: Span[Float64, ImmutAnyOrigin],
        y_error: Span[Float64, ImmutAnyOrigin],
        *,
        cap_size: Float64 = 0.0,
        var label: String = String(),
        style: SeriesStyle = SeriesStyle(),
    ) raises -> Self:
        """Consume this plot, add vertical error bars, and return it."""
        self.errorbar(
            x,
            y,
            y_error,
            cap_size=cap_size,
            label=label^,
            style=style,
        )
        return self^

    def errorbar(
        mut self,
        x: Span[Float64, ImmutAnyOrigin],
        y: Span[Float64, ImmutAnyOrigin],
        x_error: Span[Float64, ImmutAnyOrigin],
        y_error: Span[Float64, ImmutAnyOrigin],
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

    def with_errorbar(
        var self,
        x: Span[Float64, ImmutAnyOrigin],
        y: Span[Float64, ImmutAnyOrigin],
        x_error: Span[Float64, ImmutAnyOrigin],
        y_error: Span[Float64, ImmutAnyOrigin],
        *,
        cap_size: Float64 = 0.0,
        var label: String = String(),
        style: SeriesStyle = SeriesStyle(),
    ) raises -> Self:
        """Consume this plot, add horizontal and vertical errors, and return it."""
        self.errorbar(
            x,
            y,
            x_error,
            y_error,
            cap_size=cap_size,
            label=label^,
            style=style,
        )
        return self^

    def bar(
        mut self,
        x: Span[Float64, ImmutAnyOrigin],
        height: Span[Float64, ImmutAnyOrigin],
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

    def with_bar(
        var self,
        x: Span[Float64, ImmutAnyOrigin],
        height: Span[Float64, ImmutAnyOrigin],
        *,
        width: Float64 = 0.8,
        baseline: Float64 = 0.0,
        var label: String = String(),
        style: SeriesStyle = SeriesStyle(),
    ) raises -> Self:
        """Consume this plot, add numeric bars, and return the updated plot."""
        self.bar(
            x,
            height,
            width=width,
            baseline=baseline,
            label=label^,
            style=style,
        )
        return self^

    def bar(
        mut self,
        categories: Span[String, _],
        height: Span[Float64, ImmutAnyOrigin],
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

    def with_bar(
        var self,
        categories: Span[String, _],
        height: Span[Float64, ImmutAnyOrigin],
        *,
        width: Float64 = 0.8,
        baseline: Float64 = 0.0,
        var label: String = String(),
        style: SeriesStyle = SeriesStyle(),
    ) raises -> Self:
        """Consume this plot, add categorical bars, and return the updated plot."""
        self.bar(
            categories,
            height,
            width=width,
            baseline=baseline,
            label=label^,
            style=style,
        )
        return self^

    def histogram(
        mut self,
        data: Span[Float64, ImmutAnyOrigin],
        *,
        bins: Int = 10,
        var label: String = String(),
        style: SeriesStyle = SeriesStyle(),
    ) raises:
        """Add an equal-width histogram over the observed finite range."""
        self._figure.histogram(data, bins=bins, label=label^, style=style)

    def with_histogram(
        var self,
        data: Span[Float64, ImmutAnyOrigin],
        *,
        bins: Int = 10,
        var label: String = String(),
        style: SeriesStyle = SeriesStyle(),
    ) raises -> Self:
        """Consume this plot, add an observed-range histogram, and return it."""
        self.histogram(data, bins=bins, label=label^, style=style)
        return self^

    def histogram(
        mut self,
        data: Span[Float64, ImmutAnyOrigin],
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

    def with_histogram(
        var self,
        data: Span[Float64, ImmutAnyOrigin],
        range_lo: Float64,
        range_hi: Float64,
        *,
        bins: Int = 10,
        var label: String = String(),
        style: SeriesStyle = SeriesStyle(),
    ) raises -> Self:
        """Consume this plot, add a fixed-range histogram, and return it."""
        self.histogram(
            data,
            range_lo,
            range_hi,
            bins=bins,
            label=label^,
            style=style,
        )
        return self^

    def title(mut self, var text: String):
        """Set the plot title exactly as supplied."""
        self._figure.set_title(text^)

    def with_title(var self, var text: String) -> Self:
        """Consume this plot, set its title, and return the updated plot."""
        self.title(text^)
        return self^

    def xlabel(mut self, var text: String):
        """Set the x-axis label exactly as supplied."""
        self._figure.set_x_label(text^)

    def with_xlabel(var self, var text: String) -> Self:
        """Consume this plot, set its x-axis label, and return it."""
        self.xlabel(text^)
        return self^

    def ylabel(mut self, var text: String):
        """Set the y-axis label exactly as supplied."""
        self._figure.set_y_label(text^)

    def with_ylabel(var self, var text: String) -> Self:
        """Consume this plot, set its y-axis label, and return it."""
        self.ylabel(text^)
        return self^

    def grid(mut self, enabled: Bool = True):
        """Enable major gridlines by default, or disable them explicitly."""
        self._figure.set_grid(enabled)

    def with_grid(var self, enabled: Bool = True) -> Self:
        """Consume this plot, configure its major gridlines, and return it."""
        self.grid(enabled)
        return self^

    def xscale(mut self, scale: AxisKind):
        """Select the x-axis transform; log-domain checks occur at render time."""
        self._figure.set_x_scale(scale)

    def with_xscale(var self, scale: AxisKind) -> Self:
        """Consume this plot, select its x-axis transform, and return it."""
        self.xscale(scale)
        return self^

    def yscale(mut self, scale: AxisKind):
        """Select the y-axis transform; log-domain checks occur at render time."""
        self._figure.set_y_scale(scale)

    def with_yscale(var self, scale: AxisKind) -> Self:
        """Consume this plot, select its y-axis transform, and return it."""
        self.yscale(scale)
        return self^

    def xlim(mut self, lo: Float64, hi: Float64) raises:
        """Set finite ordered x limits using ``Figure`` validation."""
        self._figure.set_x_limits(lo, hi)

    def with_xlim(var self, lo: Float64, hi: Float64) raises -> Self:
        """Consume this plot, set validated x limits, and return it."""
        self.xlim(lo, hi)
        return self^

    def ylim(mut self, lo: Float64, hi: Float64) raises:
        """Set finite ordered y limits using ``Figure`` validation."""
        self._figure.set_y_limits(lo, hi)

    def with_ylim(var self, lo: Float64, hi: Float64) raises -> Self:
        """Consume this plot, set validated y limits, and return it."""
        self.ylim(lo, hi)
        return self^

    def clear_xlim(mut self):
        """Restore automatic x limits without changing stored series."""
        self._figure.clear_x_limits()

    def with_auto_xlim(var self) -> Self:
        """Consume this plot, restore automatic x limits, and return it."""
        self.clear_xlim()
        return self^

    def clear_ylim(mut self):
        """Restore automatic y limits without changing stored series."""
        self._figure.clear_y_limits()

    def with_auto_ylim(var self) -> Self:
        """Consume this plot, restore automatic y limits, and return it."""
        self.clear_ylim()
        return self^

    def xticks(
        mut self,
        positions: Span[Float64, ImmutAnyOrigin],
        labels: Span[String, _],
    ) raises:
        """Replace x ticks atomically with explicit positions and labels."""
        self._figure.set_x_ticks(positions, labels)

    def with_xticks(
        var self,
        positions: Span[Float64, ImmutAnyOrigin],
        labels: Span[String, _],
    ) raises -> Self:
        """Consume this plot, set explicit x ticks, and return it."""
        self.xticks(positions, labels)
        return self^

    def clear_xticks(mut self):
        """Restore automatic x ticks without changing the data domain."""
        self._figure.clear_x_ticks()

    def with_auto_xticks(var self) -> Self:
        """Consume this plot, restore automatic x ticks, and return it."""
        self.clear_xticks()
        return self^

    def yticks(
        mut self,
        positions: Span[Float64, ImmutAnyOrigin],
        labels: Span[String, _],
    ) raises:
        """Replace y ticks atomically with explicit positions and labels."""
        self._figure.set_y_ticks(positions, labels)

    def with_yticks(
        var self,
        positions: Span[Float64, ImmutAnyOrigin],
        labels: Span[String, _],
    ) raises -> Self:
        """Consume this plot, set explicit y ticks, and return it."""
        self.yticks(positions, labels)
        return self^

    def clear_yticks(mut self):
        """Restore automatic y ticks without changing the data domain."""
        self._figure.clear_y_ticks()

    def with_auto_yticks(var self) -> Self:
        """Consume this plot, restore automatic y ticks, and return it."""
        self.clear_yticks()
        return self^

    def legend(mut self, position: LegendPosition = LegendPosition.UPPER_RIGHT):
        """Show the legend at ``position`` or suppress it with ``NONE``."""
        self._figure.set_legend(position)

    def with_legend(
        var self, position: LegendPosition = LegendPosition.UPPER_RIGHT
    ) -> Self:
        """Consume this plot, set its legend position, and return it."""
        self.legend(position)
        return self^

    def build_render_plan(
        self,
        width: Float64,
        height: Float64,
        margins: Margins,
    ) raises -> RenderPlan:
        """Lower this plot with explicit geometry to a backend-neutral plan."""
        return _build_figure_render_plan(self._figure, width, height, margins)

    def build_render_plan(
        self,
        width: Float64 = 640.0,
        height: Float64 = 480.0,
    ) raises -> RenderPlan:
        """Lower this plot using Sen's default canvas and margins."""
        return _build_figure_render_plan(
            self._figure,
            width,
            height,
            Margins(40.0, 12.0, 12.0, 28.0),
        )

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
        width: Float64,
        height: Float64,
        margins: Margins,
    ) raises:
        """Render with explicit geometry and replace ``path`` with its SVG."""
        var svg = _render_figure_svg(self._figure, width, height, margins)
        _write_svg(path, svg)

    def save_svg(
        self,
        path: StringSlice,
        width: Float64 = 640.0,
        height: Float64 = 480.0,
    ) raises:
        """Render once with the requested size and replace ``path`` with its SVG."""
        var svg = _render_figure_svg(self._figure, width, height)
        _write_svg(path, svg)
