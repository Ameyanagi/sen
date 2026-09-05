"""Opt-in font measurements using the published mojo-kumihan ==0.1.0 package.

Import this module only in a consumer environment containing Kumihan. The main
``sen`` import remains independent of it. This nominal adapter matches the
encoder's no-kerning/no-optional-ligature mode; complex shaping is out of scope.
"""

from kumihan import FontFace, TextStyle, shape_nominal
from sen import TextMetrics
from std.math import isfinite
from std.collections import Optional


struct KumihanTextMetrics(TextMetrics):
    """Measure known horizontal Latin/CJK font advances without host discovery.

    Supply the exact SVG font family and load that same font in the SVG viewer.
    Missing glyphs raise instead of silently measuring a different fallback.
    This adapter does not promise browser-equivalent Arabic/Indic shaping or
    mark attachment; use a complete shaping provider for those scripts.
    """

    var _face: FontFace
    var _family: String
    var _font_weight: Int

    def __init__(
        out self, var face: FontFace, family: StringSlice, *, font_weight: Int = 400
    ) raises:
        if family.strip().byte_length() == 0:
            raise Error("font family must not be blank; supply the loaded SVG family")
        if font_weight < 1 or font_weight > 1000:
            raise Error("font_weight must be within 1..1000; got ", font_weight)
        self._font_weight = font_weight
        self._face = face^
        self._family = String(family)

    def font_weight(self) -> Optional[Int]:
        return self._font_weight

    def _scale(self, font_size: Float64) raises -> Float64:
        if not isfinite(font_size) or font_size <= 0.0:
            raise Error("font_size must be finite and positive; got ", font_size)
        return font_size / Float64(self._face.units_per_em())

    def ascent(self, font_size: Float64) raises -> Float64:
        var result = max(0.0, Float64(self._face.ascender()) * self._scale(font_size))
        if not isfinite(result):
            raise Error(
                "font ascent is not representable; reduce font_size from ", font_size
            )
        return result

    def descent(self, font_size: Float64) raises -> Float64:
        var result = max(0.0, -Float64(self._face.descender()) * self._scale(font_size))
        if not isfinite(result):
            raise Error(
                "font descent is not representable; reduce font_size from ", font_size
            )
        return result

    def additive_graphemes(self) -> Bool:
        return True

    def nominal_glyphs(self) -> Bool:
        return True

    def validate_family(self, family: StringSlice) raises:
        if not family == self._family:
            raise Error(
                "font family must match measured family '",
                self._family,
                "'; got '",
                family,
                "'; set Typography.with_family",
            )

    def width(self, text: StringSlice, font_size: Float64) raises -> Float64:
        var run = shape_nominal(self._face, text, TextStyle(size=font_size))
        if run.missing_glyph_count() > 0:
            raise Error(
                "text contains ",
                run.missing_glyph_count(),
                " missing glyphs; use a font covering every label",
            )
        return run.total_x_advance()

    def height(self, font_size: Float64) raises -> Float64:
        var scale = self._scale(font_size)
        var ascent = Float64(self._face.ascender()) * scale
        var descent = -Float64(self._face.descender()) * scale
        var gap = Float64(self._face.line_gap()) * scale
        var result = max(ascent, 0.0) + max(descent, 0.0) + max(gap, 0.0)
        if not isfinite(result) or result <= 0.0:
            raise Error(
                "font height must be finite and positive; got ",
                result,
                "; reduce font_size or choose valid font metrics",
            )
        return result
