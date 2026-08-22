"""Backend-neutral, device-space drawing commands produced from a Figure."""

from std.collections import List
from std.math import isfinite

from .style import LineStyle, MarkerStyle


struct _Validated:
    def __init__(out self):
        pass


struct CommandKind(Copyable, Equatable, ImplicitlyCopyable):
    """A closed vocabulary shared by deterministic rendering backends."""

    var _value: Int

    comptime BACKGROUND = CommandKind(_value=0)
    comptime FRAME = CommandKind(_value=1)
    comptime AXIS = CommandKind(_value=2)
    comptime TICK = CommandKind(_value=3)
    comptime X_LABEL = CommandKind(_value=4)
    comptime Y_LABEL = CommandKind(_value=5)
    comptime SERIES = CommandKind(_value=6)
    comptime TITLE = CommandKind(_value=7)
    comptime X_TITLE = CommandKind(_value=8)
    comptime Y_TITLE = CommandKind(_value=9)
    comptime MARKER = CommandKind(_value=10)
    comptime GRID = CommandKind(_value=11)
    comptime LEGEND_BACKGROUND = CommandKind(_value=12)
    comptime LEGEND_LINE = CommandKind(_value=13)
    comptime LEGEND_MARKER = CommandKind(_value=14)
    comptime LEGEND_TEXT = CommandKind(_value=15)
    comptime RECTANGLE = CommandKind(_value=16)
    comptime LEGEND_RECTANGLE = CommandKind(_value=17)
    comptime AREA = CommandKind(_value=18)
    comptime LEGEND_AREA = CommandKind(_value=19)

    def __init__(out self, *, _value: Int):
        self._value = _value

    def __eq__(self, other: Self) -> Bool:
        return self._value == other._value

    def validate(self) raises:
        """Reject discriminants outside Sen's closed command vocabulary."""
        if self._value < 0 or self._value > 19:
            raise Error("render command kind is outside Sen's vocabulary")


struct PlanPoint(Copyable, Equatable, ImplicitlyCopyable):
    """One finite device-space point in logical y-down coordinates."""

    var x: Float64
    var y: Float64

    def __init__(out self, x: Float64, y: Float64) raises:
        self.x = x
        self.y = y
        self.validate()

    @staticmethod
    def _from_validated(x: Float64, y: Float64) -> Self:
        return Self(x, y, _validated=_Validated())

    def __init__(out self, x: Float64, y: Float64, *, _validated: _Validated):
        self.x = x
        self.y = y

    def validate(self) raises:
        """Require finite logical device coordinates."""
        if not isfinite(self.x) or not isfinite(self.y):
            raise Error("render-plan points must be finite")

    def __eq__(self, other: Self) -> Bool:
        return self.x == other.x and self.y == other.y


struct DrawCommand(Copyable, Equatable):
    """One renderer-independent shape, text, marker, or series command."""

    var kind: CommandKind
    var x1: Float64
    var y1: Float64
    var x2: Float64
    var y2: Float64
    var points: List[PlanPoint]
    var text: String
    var color: String
    var palette_slot: Int
    var series_index: Int
    var line_width: Float64
    var line_style: LineStyle
    var marker_style: MarkerStyle

    def __init__(
        out self,
        kind: CommandKind,
        x1: Float64,
        y1: Float64,
        x2: Float64,
        y2: Float64,
        var points: List[PlanPoint],
        var text: String,
        var color: String,
        palette_slot: Int,
        series_index: Int,
        line_width: Float64,
        line_style: LineStyle,
        marker_style: MarkerStyle,
    ) raises:
        self.kind = kind
        self.x1 = x1
        self.y1 = y1
        self.x2 = x2
        self.y2 = y2
        self.points = points^
        self.text = text^
        self.color = color^
        self.palette_slot = palette_slot
        self.series_index = series_index
        self.line_width = line_width
        self.line_style = line_style
        self.marker_style = marker_style
        self.validate()

    @staticmethod
    def _from_validated(
        kind: CommandKind,
        x1: Float64,
        y1: Float64,
        x2: Float64,
        y2: Float64,
        var points: List[PlanPoint],
        var text: String,
        var color: String,
        palette_slot: Int,
        series_index: Int,
        line_width: Float64,
        line_style: LineStyle,
        marker_style: MarkerStyle,
    ) -> Self:
        return Self(
            kind,
            x1,
            y1,
            x2,
            y2,
            points^,
            text^,
            color^,
            palette_slot,
            series_index,
            line_width,
            line_style,
            marker_style,
            _validated=_Validated(),
        )

    def __init__(
        out self,
        kind: CommandKind,
        x1: Float64,
        y1: Float64,
        x2: Float64,
        y2: Float64,
        var points: List[PlanPoint],
        var text: String,
        var color: String,
        palette_slot: Int,
        series_index: Int,
        line_width: Float64,
        line_style: LineStyle,
        marker_style: MarkerStyle,
        *,
        _validated: _Validated,
    ):
        self.kind = kind
        self.x1 = x1
        self.y1 = y1
        self.x2 = x2
        self.y2 = y2
        self.points = points^
        self.text = text^
        self.color = color^
        self.palette_slot = palette_slot
        self.series_index = series_index
        self.line_width = line_width
        self.line_style = line_style
        self.marker_style = marker_style

    def validate(self) raises:
        """Validate generic fields and the selected primitive's safe contract."""
        self.kind.validate()
        if (
            not isfinite(self.x1)
            or not isfinite(self.y1)
            or not isfinite(self.x2)
            or not isfinite(self.y2)
        ):
            raise Error("render command geometry must be finite")
        if not isfinite(self.line_width) or self.line_width < 0.0:
            raise Error("render command line width must be finite and nonnegative")
        if self.palette_slot < -1 or self.palette_slot > 5:
            raise Error("render command palette slot must be within -1..5")
        if self.series_index < -1:
            raise Error("render command series index must be at least -1")
        if self.line_style._value < 0 or self.line_style._value > 3:
            raise Error("render command line style is outside Sen's vocabulary")
        if self.marker_style._value < 0 or self.marker_style._value > 7:
            raise Error("render command marker style is outside Sen's vocabulary")
        for index in range(len(self.points)):
            self.points[index].validate()

        var is_rectangle = (
            self.kind == CommandKind.BACKGROUND
            or self.kind == CommandKind.FRAME
            or self.kind == CommandKind.LEGEND_BACKGROUND
            or self.kind == CommandKind.RECTANGLE
            or self.kind == CommandKind.LEGEND_RECTANGLE
            or self.kind == CommandKind.LEGEND_AREA
        )
        if is_rectangle and (self.x2 < 0.0 or self.y2 < 0.0):
            raise Error("render rectangle width and height must be nonnegative")

        if self.kind == CommandKind.SERIES:
            if len(self.points) == 0:
                raise Error("render series commands require at least one point")
            if self.color.byte_length() == 0:
                raise Error("render series commands require a color")
            if self.line_width <= 0.0:
                raise Error("render series commands require a positive line width")
            if self.series_index < 0:
                raise Error("render data commands require a nonnegative series index")
        elif self.kind == CommandKind.AREA:
            if len(self.points) < 3:
                raise Error("render area commands require at least three points")
            if self.color.byte_length() == 0:
                raise Error("render area commands require a color")
            if self.line_width <= 0.0:
                raise Error("render area commands require a positive line width")
            if self.series_index < 0:
                raise Error("render data commands require a nonnegative series index")
        elif self.kind == CommandKind.MARKER:
            if self.palette_slot < 0 and self.color.byte_length() == 0:
                raise Error("render marker commands require a palette slot or color")
            if self.series_index < 0:
                raise Error("render data commands require a nonnegative series index")
        elif self.kind == CommandKind.RECTANGLE:
            if self.color.byte_length() == 0:
                raise Error("render rectangle commands require a color")
            if self.series_index < 0:
                raise Error("render data commands require a nonnegative series index")
        elif self.kind == CommandKind.LEGEND_LINE:
            if self.color.byte_length() == 0:
                raise Error("render legend line commands require a color")
            if self.line_width <= 0.0:
                raise Error("render legend line commands require a positive line width")
        elif self.kind == CommandKind.LEGEND_MARKER:
            if self.palette_slot < 0 and self.color.byte_length() == 0:
                raise Error(
                    "render legend marker commands require a palette slot or color"
                )
        elif self.kind == CommandKind.LEGEND_RECTANGLE:
            if self.color.byte_length() == 0:
                raise Error("render legend rectangle commands require a color")
        elif self.kind == CommandKind.LEGEND_AREA:
            if self.color.byte_length() == 0:
                raise Error("render legend area commands require a color")
            if self.line_width <= 0.0:
                raise Error("render legend area commands require a positive line width")

    def __eq__(self, other: Self) -> Bool:
        if (
            self.kind != other.kind
            or self.x1 != other.x1
            or self.y1 != other.y1
            or self.x2 != other.x2
            or self.y2 != other.y2
            or self.text != other.text
            or self.color != other.color
            or self.palette_slot != other.palette_slot
            or self.series_index != other.series_index
            or self.line_width != other.line_width
            or self.line_style != other.line_style
            or self.marker_style != other.marker_style
            or len(self.points) != len(other.points)
        ):
            return False
        for index in range(len(self.points)):
            if self.points[index] != other.points[index]:
                return False
        return True


struct RenderPlan(Copyable, Equatable):
    """A complete ordered device-space plan independent of output encoding."""

    var width: Float64
    var height: Float64
    var plot_x: Float64
    var plot_y: Float64
    var plot_width: Float64
    var plot_height: Float64
    var commands: List[DrawCommand]

    def __init__(
        out self,
        width: Float64,
        height: Float64,
        plot_x: Float64,
        plot_y: Float64,
        plot_width: Float64,
        plot_height: Float64,
        var commands: List[DrawCommand],
    ) raises:
        self.width = width
        self.height = height
        self.plot_x = plot_x
        self.plot_y = plot_y
        self.plot_width = plot_width
        self.plot_height = plot_height
        self.commands = commands^
        self.validate()

    @staticmethod
    def _from_validated(
        width: Float64,
        height: Float64,
        plot_x: Float64,
        plot_y: Float64,
        plot_width: Float64,
        plot_height: Float64,
        var commands: List[DrawCommand],
    ) -> Self:
        return Self(
            width,
            height,
            plot_x,
            plot_y,
            plot_width,
            plot_height,
            commands^,
            _validated=_Validated(),
        )

    def __init__(
        out self,
        width: Float64,
        height: Float64,
        plot_x: Float64,
        plot_y: Float64,
        plot_width: Float64,
        plot_height: Float64,
        var commands: List[DrawCommand],
        *,
        _validated: _Validated,
    ):
        self.width = width
        self.height = height
        self.plot_x = plot_x
        self.plot_y = plot_y
        self.plot_width = plot_width
        self.plot_height = plot_height
        self.commands = commands^

    def command_count(self) -> Int:
        """Return the ordered command count without allocation."""
        return len(self.commands)

    def command(self, index: Int) raises -> ref[self.commands[index]] DrawCommand:
        """Return one ordered command by checked index."""
        if index < 0 or index >= len(self.commands):
            raise Error("render command index is out of bounds")
        return self.commands[index]

    def validate(self) raises:
        """Validate finite positive geometry and every ordered command."""
        if (
            not isfinite(self.width)
            or not isfinite(self.height)
            or self.width <= 0.0
            or self.height <= 0.0
        ):
            raise Error("render-plan figure size must be finite and positive")
        if (
            not isfinite(self.plot_x)
            or not isfinite(self.plot_y)
            or not isfinite(self.plot_width)
            or not isfinite(self.plot_height)
            or self.plot_x < 0.0
            or self.plot_y < 0.0
            or self.plot_width <= 0.0
            or self.plot_height <= 0.0
            or self.plot_x + self.plot_width > self.width
            or self.plot_y + self.plot_height > self.height
        ):
            raise Error("render-plan plot rectangle must fit within the figure")
        if len(self.commands) == 0:
            raise Error("render-plan must contain at least one command")
        for index in range(len(self.commands)):
            self.commands[index].validate()

    def __eq__(self, other: Self) -> Bool:
        if (
            self.width != other.width
            or self.height != other.height
            or self.plot_x != other.plot_x
            or self.plot_y != other.plot_y
            or self.plot_width != other.plot_width
            or self.plot_height != other.plot_height
            or len(self.commands) != len(other.commands)
        ):
            return False
        for index in range(len(self.commands)):
            if self.commands[index] != other.commands[index]:
                return False
        return True
