"""Physical figure size and export-resolution configuration."""

from std.math import floor, isfinite


struct FigureConfig(Copyable, Equatable, ImplicitlyCopyable):
    """Independent physical size and export DPI for a figure.

    Width and height are stored in inches. Logical SVG coordinates use Sen's
    stable reference density of 100 units per inch, while raster dimensions
    use the independently configured export DPI. Pixel-based sizing is a
    convenience conversion through the current DPI and does not change it.
    """

    var _width: Float64
    var _height: Float64
    var _dpi: Float64

    def __init__(out self):
        """Construct Sen's 6.4 by 4.8 inch, 100 DPI default canvas."""
        self._width = 6.4
        self._height = 4.8
        self._dpi = 100.0

    def __init__(
        out self, width: Float64, height: Float64, *, dpi: Float64 = 100.0
    ) raises:
        """Construct a validated physical size and independent export DPI."""
        self._width = width
        self._height = height
        self._dpi = dpi
        self.validate()

    def with_size(self, width: Float64, height: Float64) raises -> Self:
        """Return a copy with a physical size in inches and unchanged DPI."""
        var result = Self(width, height, dpi=self._dpi)
        return result^

    def with_size_px(self, width_px: Int, height_px: Int) raises -> Self:
        """Return a copy sized by pixels at the current, unchanged export DPI."""
        if width_px <= 0 or height_px <= 0:
            raise Error(
                "figure pixel size must be positive; got width=",
                width_px,
                ", height=",
                height_px,
            )
        return Self(
            Float64(width_px) / self._dpi,
            Float64(height_px) / self._dpi,
            dpi=self._dpi,
        )

    def with_dpi(self, dpi: Float64) raises -> Self:
        """Return a copy with export DPI changed and physical size unchanged."""
        var result = Self(self._width, self._height, dpi=dpi)
        return result^

    def validate(self) raises:
        """Validate positive finite dimensions and representable raster extents."""
        if not isfinite(self._width) or not isfinite(self._height):
            raise Error(
                "figure physical size must be finite; got width=",
                self._width,
                ", height=",
                self._height,
            )
        if self._width <= 0.0 or self._height <= 0.0:
            raise Error(
                "figure physical size must be positive; got width=",
                self._width,
                ", height=",
                self._height,
            )
        if not isfinite(self._dpi):
            raise Error("figure export DPI must be finite; got ", self._dpi)
        if self._dpi <= 0.0:
            raise Error("figure export DPI must be positive; got ", self._dpi)

        var raster_width = self._width * self._dpi
        var raster_height = self._height * self._dpi
        if raster_width < 0.5 or raster_height < 0.5:
            raise Error(
                (
                    "figure raster size must round to at least one pixel per axis; got"
                    " width="
                ),
                raster_width,
                ", height=",
                raster_height,
            )
        if (
            not isfinite(raster_width)
            or not isfinite(raster_height)
            or raster_width > 9.0e18
            or raster_height > 9.0e18
        ):
            raise Error(
                "figure raster size exceeds the supported integer extent; got width=",
                raster_width,
                ", height=",
                raster_height,
            )

        var logical_width = self._width * 100.0
        var logical_height = self._height * 100.0
        if (
            not isfinite(logical_width)
            or not isfinite(logical_height)
            or logical_width > 9.0e15
            or logical_height > 9.0e15
        ):
            raise Error(
                "figure logical size exceeds the SVG fixed-decimal extent; got width=",
                logical_width,
                ", height=",
                logical_height,
            )

    def width(self) -> Float64:
        """Return physical width in inches."""
        return self._width

    def height(self) -> Float64:
        """Return physical height in inches."""
        return self._height

    def dpi(self) -> Float64:
        """Return export dots per inch."""
        return self._dpi

    def logical_width(self) -> Float64:
        """Return SVG logical width at Sen's fixed 100-unit reference density."""
        return self._width * 100.0

    def logical_height(self) -> Float64:
        """Return SVG logical height at Sen's fixed 100-unit reference density."""
        return self._height * 100.0

    def raster_width(self) -> Int:
        """Return pixel width rounded to nearest, with positive ties rounded up."""
        return Int(floor(self._width * self._dpi + 0.5))

    def raster_height(self) -> Int:
        """Return pixel height rounded to nearest, with positive ties rounded up."""
        return Int(floor(self._height * self._dpi + 0.5))

    def __eq__(self, other: Self) -> Bool:
        """Return exact equality of physical size and export DPI."""
        return (
            self._width == other._width
            and self._height == other._height
            and self._dpi == other._dpi
        )
