"""Renderer-independent scientific plotting semantics for Mojo."""

from .figure_config import FigureConfig
from .layout import Margins, Rect, plot_area
from .lowering import build_render_plan
from .plot import Plot
from .render_plan import CommandKind, DrawCommand, PlanPoint, RenderPlan
from .scale import (
    LinearScale,
    LogScale,
    StickyEdges,
    linear_ticks,
    log_ticks,
    view_bounds,
)
from .series import (
    AreaSeries,
    AxisKind,
    DataBounds,
    DataRectangle,
    Figure,
    LegendPosition,
    LineSeries,
    MissingPolicy,
    PlotPoint,
    RectangleSeries,
    ScatterSeries,
    StepMode,
)
from .style import LineCap, LineJoin, LineStyle, MarkerStyle, SeriesStyle
from .svg import encode_svg, render_svg, save_svg, write_svg
from .text import Text, TextKind
from .theme import TextLocale, Theme, Typography
from .typst import TypstOptions
