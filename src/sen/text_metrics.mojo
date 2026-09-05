"""Deterministic fallback metrics for SVG text layout.

These estimates deliberately avoid host font discovery. They provide stable
layout inputs when a renderer cannot supply actual glyph metrics; they are not
intended to replace font shaping or measurement by an output backend.
"""

from std.math import isfinite
from std.collections import Optional


def _validate_font_size(font_size: Float64) raises:
    if not isfinite(font_size) or font_size <= 0.0:
        raise Error("font size must be finite and positive; got ", font_size)


def _is_control(value: Int) -> Bool:
    return value < 0x20 or (value >= 0x7F and value <= 0x9F)


def _is_default_ignorable(value: Int) -> Bool:
    # Unicode Default_Ignorable_Code_Point ranges that commonly occur in plot
    # labels, including selectors, join controls, bidi controls, and tags.
    return (
        value == 0x00AD
        or value == 0x034F
        or value == 0x061C
        or value == 0x115F
        or value == 0x1160
        or (value >= 0x17B4 and value <= 0x17B5)
        or (value >= 0x180B and value <= 0x180F)
        or (value >= 0x200B and value <= 0x200F)
        or (value >= 0x202A and value <= 0x202E)
        or (value >= 0x2060 and value <= 0x206F)
        or value == 0x3164
        or (value >= 0xFE00 and value <= 0xFE0F)
        or value == 0xFEFF
        or (value >= 0xFFA0 and value <= 0xFFA0)
        or (value >= 0xFFF0 and value <= 0xFFF8)
        or (value >= 0x1BCA0 and value <= 0x1BCAF)
        or (value >= 0x1D173 and value <= 0x1D17A)
        or (value >= 0xE0000 and value <= 0xE0FFF)
    )


def _is_combining_mark(value: Int) -> Bool:
    # The principal combining-mark blocks plus script-specific marks used by
    # modern writing systems. A combining mark following a base remains in the
    # base's extended grapheme cluster; this classification matters most for a
    # cluster that contains no renderable base of its own.
    return (
        (value >= 0x0300 and value <= 0x036F)
        or (value >= 0x0483 and value <= 0x0489)
        or (value >= 0x0591 and value <= 0x05BD)
        or value == 0x05BF
        or (value >= 0x05C1 and value <= 0x05C2)
        or (value >= 0x05C4 and value <= 0x05C5)
        or value == 0x05C7
        or (value >= 0x0610 and value <= 0x061A)
        or (value >= 0x064B and value <= 0x065F)
        or value == 0x0670
        or (value >= 0x06D6 and value <= 0x06DC)
        or (value >= 0x06DF and value <= 0x06E4)
        or (value >= 0x06E7 and value <= 0x06E8)
        or (value >= 0x06EA and value <= 0x06ED)
        or value == 0x0711
        or (value >= 0x0730 and value <= 0x074A)
        or (value >= 0x07A6 and value <= 0x07B0)
        or (value >= 0x07EB and value <= 0x07F3)
        or (value >= 0x0816 and value <= 0x082D)
        or (value >= 0x0859 and value <= 0x085B)
        or (value >= 0x0897 and value <= 0x0902)
        or value == 0x093A
        or value == 0x093C
        or (value >= 0x0941 and value <= 0x0948)
        or value == 0x094D
        or (value >= 0x0951 and value <= 0x0957)
        or (value >= 0x0962 and value <= 0x0963)
        or (value >= 0x0981 and value <= 0x0981)
        or value == 0x09BC
        or (value >= 0x09C1 and value <= 0x09C4)
        or value == 0x09CD
        or (value >= 0x0A01 and value <= 0x0A02)
        or value == 0x0A3C
        or (value >= 0x0A41 and value <= 0x0A42)
        or (value >= 0x0A47 and value <= 0x0A48)
        or (value >= 0x0A4B and value <= 0x0A4D)
        or (value >= 0x0A70 and value <= 0x0A71)
        or (value >= 0x0A81 and value <= 0x0A82)
        or value == 0x0ABC
        or (value >= 0x0AC1 and value <= 0x0AC8)
        or value == 0x0ACD
        or (value >= 0x0AE2 and value <= 0x0AE3)
        or (value >= 0x0B01 and value <= 0x0B01)
        or value == 0x0B3C
        or value == 0x0B3F
        or (value >= 0x0B41 and value <= 0x0B44)
        or value == 0x0B4D
        or (value >= 0x0B55 and value <= 0x0B56)
        or (value >= 0x0B62 and value <= 0x0B63)
        or value == 0x0B82
        or value == 0x0BCD
        or value == 0x0C00
        or value == 0x0C04
        or (value >= 0x0C3C and value <= 0x0C40)
        or (value >= 0x0C46 and value <= 0x0C48)
        or (value >= 0x0C4A and value <= 0x0C4D)
        or (value >= 0x0C55 and value <= 0x0C56)
        or (value >= 0x0C62 and value <= 0x0C63)
        or value == 0x0C81
        or value == 0x0CBC
        or value == 0x0CBF
        or value == 0x0CC6
        or (value >= 0x0CCC and value <= 0x0CCD)
        or (value >= 0x0CE2 and value <= 0x0CE3)
        or (value >= 0x0D00 and value <= 0x0D01)
        or (value >= 0x0D3B and value <= 0x0D3C)
        or (value >= 0x0D41 and value <= 0x0D44)
        or value == 0x0D4D
        or (value >= 0x0D62 and value <= 0x0D63)
        or value == 0x0D81
        or value == 0x0DCA
        or (value >= 0x0DD2 and value <= 0x0DD4)
        or value == 0x0DD6
        or value == 0x0E31
        or (value >= 0x0E34 and value <= 0x0E3A)
        or (value >= 0x0E47 and value <= 0x0E4E)
        or value == 0x0EB1
        or (value >= 0x0EB4 and value <= 0x0EBC)
        or (value >= 0x0EC8 and value <= 0x0ECE)
        or (value >= 0x0F18 and value <= 0x0F19)
        or value == 0x0F35
        or value == 0x0F37
        or value == 0x0F39
        or (value >= 0x0F71 and value <= 0x0F84)
        or (value >= 0x0F86 and value <= 0x0F87)
        or (value >= 0x0F8D and value <= 0x0FBC)
        or value == 0x0FC6
        or (value >= 0x102D and value <= 0x1030)
        or (value >= 0x1032 and value <= 0x1037)
        or (value >= 0x1039 and value <= 0x103A)
        or (value >= 0x103D and value <= 0x103E)
        or (value >= 0x1058 and value <= 0x1059)
        or (value >= 0x105E and value <= 0x1060)
        or (value >= 0x1071 and value <= 0x1074)
        or value == 0x1082
        or (value >= 0x1085 and value <= 0x1086)
        or value == 0x108D
        or value == 0x109D
        or (value >= 0x135D and value <= 0x135F)
        or (value >= 0x1712 and value <= 0x1715)
        or (value >= 0x1732 and value <= 0x1734)
        or (value >= 0x1752 and value <= 0x1753)
        or (value >= 0x1772 and value <= 0x1773)
        or (value >= 0x17B4 and value <= 0x17B5)
        or (value >= 0x17B7 and value <= 0x17BD)
        or value == 0x17C6
        or (value >= 0x17C9 and value <= 0x17D3)
        or value == 0x17DD
        or (value >= 0x180B and value <= 0x180D)
        or value == 0x1885
        or value == 0x1886
        or value == 0x18A9
        or (value >= 0x1920 and value <= 0x1922)
        or (value >= 0x1927 and value <= 0x1928)
        or value == 0x1932
        or (value >= 0x1939 and value <= 0x193B)
        or (value >= 0x1A17 and value <= 0x1A18)
        or value == 0x1A1B
        or value == 0x1A56
        or (value >= 0x1A58 and value <= 0x1A5E)
        or value == 0x1A60
        or value == 0x1A62
        or (value >= 0x1A65 and value <= 0x1A6C)
        or (value >= 0x1A73 and value <= 0x1A7C)
        or value == 0x1A7F
        or (value >= 0x1AB0 and value <= 0x1ACE)
        or (value >= 0x1B00 and value <= 0x1B03)
        or value == 0x1B34
        or (value >= 0x1B36 and value <= 0x1B3A)
        or value == 0x1B3C
        or value == 0x1B42
        or (value >= 0x1B6B and value <= 0x1B73)
        or (value >= 0x1B80 and value <= 0x1B81)
        or (value >= 0x1BA2 and value <= 0x1BA5)
        or (value >= 0x1BA8 and value <= 0x1BA9)
        or (value >= 0x1BAB and value <= 0x1BAD)
        or value == 0x1BE6
        or (value >= 0x1BE8 and value <= 0x1BE9)
        or value == 0x1BED
        or (value >= 0x1BEF and value <= 0x1BF1)
        or (value >= 0x1C2C and value <= 0x1C33)
        or (value >= 0x1C36 and value <= 0x1C37)
        or (value >= 0x1CD0 and value <= 0x1CD2)
        or (value >= 0x1CD4 and value <= 0x1CE0)
        or (value >= 0x1CE2 and value <= 0x1CE8)
        or value == 0x1CED
        or value == 0x1CF4
        or (value >= 0x1CF8 and value <= 0x1CF9)
        or (value >= 0x1DC0 and value <= 0x1DFF)
        or (value >= 0x20D0 and value <= 0x20FF)
        or (value >= 0x2CEF and value <= 0x2CF1)
        or value == 0x2D7F
        or (value >= 0x2DE0 and value <= 0x2DFF)
        or (value >= 0x302A and value <= 0x302F)
        or value == 0x3099
        or value == 0x309A
        or (value >= 0xA66F and value <= 0xA672)
        or (value >= 0xA674 and value <= 0xA67D)
        or value == 0xA69E
        or value == 0xA69F
        or (value >= 0xA6F0 and value <= 0xA6F1)
        or value == 0xA802
        or value == 0xA806
        or value == 0xA80B
        or (value >= 0xA825 and value <= 0xA826)
        or value == 0xA82C
        or (value >= 0xA8C4 and value <= 0xA8C5)
        or (value >= 0xA8E0 and value <= 0xA8F1)
        or value == 0xA8FF
        or (value >= 0xA926 and value <= 0xA92D)
        or (value >= 0xA947 and value <= 0xA951)
        or (value >= 0xA980 and value <= 0xA982)
        or value == 0xA9B3
        or (value >= 0xA9B6 and value <= 0xA9B9)
        or value == 0xA9BC
        or value == 0xA9E5
        or (value >= 0xAA29 and value <= 0xAA2E)
        or (value >= 0xAA31 and value <= 0xAA32)
        or (value >= 0xAA35 and value <= 0xAA36)
        or value == 0xAA43
        or value == 0xAA4C
        or value == 0xAA7C
        or value == 0xAAB0
        or (value >= 0xAAB2 and value <= 0xAAB4)
        or (value >= 0xAAB7 and value <= 0xAAB8)
        or (value >= 0xAABE and value <= 0xAABF)
        or value == 0xAAC1
        or (value >= 0xAAEC and value <= 0xAAED)
        or value == 0xAAF6
        or value == 0xABE5
        or value == 0xABE8
        or value == 0xABED
        or value == 0xFB1E
        or (value >= 0xFE20 and value <= 0xFE2F)
        or (value >= 0x101FD and value <= 0x101FD)
        or (value >= 0x102E0 and value <= 0x102E0)
        or (value >= 0x10376 and value <= 0x1037A)
        or (value >= 0x10A01 and value <= 0x10A0F)
        or (value >= 0x10A38 and value <= 0x10A3F)
        or (value >= 0x10AE5 and value <= 0x10AE6)
        or (value >= 0x10D24 and value <= 0x10D27)
        or (value >= 0x10EAB and value <= 0x10EAC)
        or (value >= 0x10EFD and value <= 0x10EFF)
        or (value >= 0x10F46 and value <= 0x10F50)
        or (value >= 0x10F82 and value <= 0x10F85)
        or (value >= 0x11001 and value <= 0x11001)
        or (value >= 0x11038 and value <= 0x11046)
        or (value >= 0x11070 and value <= 0x11070)
        or (value >= 0x11073 and value <= 0x11074)
        or (value >= 0x1107F and value <= 0x11081)
        or (value >= 0x110B3 and value <= 0x110B6)
        or (value >= 0x110B9 and value <= 0x110BA)
        or (value >= 0x11100 and value <= 0x11102)
        or (value >= 0x11127 and value <= 0x1112B)
        or (value >= 0x1112D and value <= 0x11134)
        or value == 0x11173
        or (value >= 0x11180 and value <= 0x11181)
        or (value >= 0x111B6 and value <= 0x111BE)
        or value == 0x111C9
        or (value >= 0x111CA and value <= 0x111CC)
        or value == 0x1122F
        or (value >= 0x11231 and value <= 0x11234)
        or value == 0x11236
        or value == 0x11237
        or value == 0x1123E
        or value == 0x11241
        or (value >= 0x112DF and value <= 0x112DF)
        or (value >= 0x112E3 and value <= 0x112EA)
        or (value >= 0x11300 and value <= 0x11301)
        or (value >= 0x1133B and value <= 0x1133C)
        or value == 0x11340
        or value == 0x11366
        or (value >= 0x1136B and value <= 0x11374)
        or (value >= 0x11438 and value <= 0x11446)
        or value == 0x1145E
        or (value >= 0x114B3 and value <= 0x114B8)
        or value == 0x114BA
        or (value >= 0x114BF and value <= 0x114C0)
        or value == 0x114C2
        or (value >= 0x115B2 and value <= 0x115B5)
        or (value >= 0x115BC and value <= 0x115BD)
        or value == 0x115BF
        or value == 0x115C0
        or (value >= 0x115DC and value <= 0x115DD)
        or (value >= 0x11633 and value <= 0x1163A)
        or value == 0x1163D
        or value == 0x1163F
        or value == 0x11640
        or value == 0x116AB
        or value == 0x116AD
        or (value >= 0x116B0 and value <= 0x116B7)
        or value == 0x1171D
        or (value >= 0x1171F and value <= 0x1172B)
        or (value >= 0x1182F and value <= 0x1183A)
        or (value >= 0x11930 and value <= 0x11930)
        or (value >= 0x1193B and value <= 0x1193E)
        or value == 0x11943
        or (value >= 0x119D4 and value <= 0x119D7)
        or (value >= 0x119DA and value <= 0x119DB)
        or value == 0x119E0
        or (value >= 0x11A01 and value <= 0x11A0A)
        or (value >= 0x11A33 and value <= 0x11A38)
        or (value >= 0x11A3B and value <= 0x11A3E)
        or value == 0x11A47
        or (value >= 0x11A51 and value <= 0x11A56)
        or (value >= 0x11A59 and value <= 0x11A5B)
        or (value >= 0x11A8A and value <= 0x11A99)
        or (value >= 0x11C30 and value <= 0x11C36)
        or value == 0x11C38
        or value == 0x11C3D
        or value == 0x11C3F
        or (value >= 0x11C92 and value <= 0x11CA7)
        or (value >= 0x11CAA and value <= 0x11CB0)
        or (value >= 0x11CB2 and value <= 0x11CB3)
        or (value >= 0x11CB5 and value <= 0x11CB6)
        or (value >= 0x11D31 and value <= 0x11D36)
        or value == 0x11D3A
        or (value >= 0x11D3C and value <= 0x11D3D)
        or value == 0x11D3F
        or value == 0x11D45
        or value == 0x11D47
        or (value >= 0x11D90 and value <= 0x11D91)
        or value == 0x11D95
        or value == 0x11D97
        or (value >= 0x11EF3 and value <= 0x11EF4)
        or (value >= 0x11F00 and value <= 0x11F01)
        or (value >= 0x11F36 and value <= 0x11F3A)
        or value == 0x11F40
        or value == 0x11F42
        or (value >= 0x13440 and value <= 0x13440)
        or (value >= 0x13447 and value <= 0x13455)
        or (value >= 0x1611E and value <= 0x16129)
        or (value >= 0x1612D and value <= 0x1612F)
        or (value >= 0x16AF0 and value <= 0x16AF4)
        or (value >= 0x16B30 and value <= 0x16B36)
        or value == 0x16F4F
        or (value >= 0x16F8F and value <= 0x16F92)
        or (value >= 0x16FE4 and value <= 0x16FE4)
        or (value >= 0x1BC9D and value <= 0x1BC9E)
        or (value >= 0x1CF00 and value <= 0x1CF46)
        or (value >= 0x1D167 and value <= 0x1D169)
        or (value >= 0x1D17B and value <= 0x1D182)
        or (value >= 0x1D185 and value <= 0x1D18B)
        or (value >= 0x1D1AA and value <= 0x1D1AD)
        or (value >= 0x1D242 and value <= 0x1D244)
        or (value >= 0x1DA00 and value <= 0x1DA36)
        or (value >= 0x1DA3B and value <= 0x1DA6C)
        or value == 0x1DA75
        or value == 0x1DA84
        or (value >= 0x1DA9B and value <= 0x1DA9F)
        or (value >= 0x1DAA1 and value <= 0x1DAAF)
        or (value >= 0x1E000 and value <= 0x1E02A)
        or (value >= 0x1E08F and value <= 0x1E08F)
        or (value >= 0x1E130 and value <= 0x1E136)
        or value == 0x1E2AE
        or (value >= 0x1E2EC and value <= 0x1E2EF)
        or (value >= 0x1E4EC and value <= 0x1E4EF)
        or (value >= 0x1E5EE and value <= 0x1E5EF)
        or (value >= 0x1E6E3 and value <= 0x1E6E3)
        or (value >= 0x1E6E6 and value <= 0x1E6E6)
        or (value >= 0x1E6EE and value <= 0x1E6EF)
        or (value >= 0x1E6F5 and value <= 0x1E6F5)
        or (value >= 0x1E8D0 and value <= 0x1E8D6)
        or (value >= 0x1E944 and value <= 0x1E94A)
        or (value >= 0xE0100 and value <= 0xE01EF)
    )


def _is_cjk_or_wide(value: Int) -> Bool:
    # This intentionally classifies CJK scripts, not merely terminal EAW=W/F.
    # Halfwidth kana and Hangul therefore still receive a readable one-em SVG
    # fallback, while all current supplementary Han extensions are covered.
    return (
        (value >= 0x02EA and value <= 0x02EB)
        or (value >= 0x1100 and value <= 0x11FF)
        or (value >= 0x2E80 and value <= 0xA4CF)
        or (value >= 0xA960 and value <= 0xA97F)
        or (value >= 0xAC00 and value <= 0xD7FF)
        or (value >= 0xF900 and value <= 0xFAFF)
        or (value >= 0xFE10 and value <= 0xFE6F)
        or (value >= 0xFF01 and value <= 0xFFDC)
        or (value >= 0xFFE0 and value <= 0xFFE6)
        or (value >= 0x16FE0 and value <= 0x18DFF)
        or (value >= 0x1AFF0 and value <= 0x1B2FF)
        or (value >= 0x1F200 and value <= 0x1F2FF)
        or (value >= 0x20000 and value <= 0x3347F)
    )


def _is_emoji(value: Int) -> Bool:
    return (
        value == 0x00A9
        or value == 0x00AE
        or value == 0x203C
        or value == 0x2049
        or value == 0x2122
        or value == 0x2139
        or (value >= 0x2194 and value <= 0x2199)
        or (value >= 0x21A9 and value <= 0x21AA)
        or (value >= 0x231A and value <= 0x231B)
        or value == 0x2328
        or value == 0x23CF
        or (value >= 0x23E9 and value <= 0x23F3)
        or (value >= 0x23F8 and value <= 0x23FA)
        or value == 0x24C2
        or (value >= 0x25AA and value <= 0x25AB)
        or value == 0x25B6
        or value == 0x25C0
        or (value >= 0x25FB and value <= 0x25FE)
        or (value >= 0x2600 and value <= 0x27BF)
        or (value >= 0x2934 and value <= 0x2935)
        or (value >= 0x2B05 and value <= 0x2B07)
        or (value >= 0x2B1B and value <= 0x2B1C)
        or value == 0x2B50
        or value == 0x2B55
        or value == 0x3030
        or value == 0x303D
        or value == 0x3297
        or value == 0x3299
        or (value >= 0x1F000 and value <= 0x1FAFF)
    )


def _is_space(value: Int) -> Bool:
    return (
        value == 0x20
        or value == 0xA0
        or value == 0x1680
        or (value >= 0x2000 and value <= 0x200A)
        or value == 0x202F
        or value == 0x205F
    )


def _ascii_factor(value: Int) -> Float64:
    if value == 0x20:
        return 0.33
    if (
        value == 0x21
        or value == 0x22
        or value == 0x27
        or value == 0x2C
        or value == 0x2E
        or value == 0x3A
        or value == 0x3B
        or value == 0x49
        or value == 0x5B
        or value == 0x5D
        or value == 0x60
        or value == 0x66
        or value == 0x69
        or value == 0x6A
        or value == 0x6C
        or value == 0x72
        or value == 0x74
        or value == 0x7C
    ):
        return 0.35
    if (
        value == 0x23
        or value == 0x25
        or value == 0x26
        or value == 0x40
        or value == 0x4D
        or value == 0x57
        or value == 0x6D
        or value == 0x77
    ):
        return 0.8
    return 0.56


def _grapheme_factor(grapheme: StringSlice) -> Float64:
    var factor = 0.0
    var has_visible = False
    var has_wide = False
    var has_keycap = False
    for scalar in grapheme.codepoints():
        var value = Int(scalar.to_u32())
        if value == 0x20E3:
            has_keycap = True
        if _is_control(value) or _is_default_ignorable(value):
            continue
        if _is_combining_mark(value):
            continue
        has_visible = True
        if _is_cjk_or_wide(value) or _is_emoji(value):
            has_wide = True
        elif factor == 0.0:
            if _is_space(value):
                factor = 0.33
            elif value < 0x80:
                factor = _ascii_factor(value)
            else:
                factor = 0.56

    if not has_visible:
        return 0.0
    if has_wide or has_keycap:
        return 1.0
    return factor


def text_width(text: StringSlice, font_size: Float64) raises -> Float64:
    """Estimate one unwrapped SVG text run's width in logical units.

    The estimate is font-independent and deterministic. Each extended grapheme
    cluster is measured once, so emoji ZWJ sequences and regional-indicator flags
    cannot inflate layout merely because they contain multiple code points.
    """
    _validate_font_size(font_size)
    var ems = 0.0
    for grapheme in text.graphemes():
        ems += _grapheme_factor(grapheme)
    return ems * font_size


def text_height(font_size: Float64) raises -> Float64:
    """Return a deterministic 1.2-em fallback line-box height."""
    _validate_font_size(font_size)
    return font_size * 1.2


trait TextMetrics:
    """Explicit synchronous text measurement contract in SVG logical units.

    A provider owns or borrows known font data. It must reject unsupported font
    families, return finite nonnegative full-run widths, and positive line-box
    heights. Width must include shaping/kerning; layout never starts a process.
    Measurements scale linearly with font size. The SVG consumer must load the
    same font, language, and shaping configuration used by the provider.
    """

    def font_weight(self) -> Optional[Int]:
        """Select the measured face's CSS weight, or None for fallback layout."""
        return Optional[Int](400)

    def ascent(self, font_size: Float64) raises -> Float64:
        """Return the maximum extent above the baseline in logical units."""
        return self.height(font_size) * 0.8

    def descent(self, font_size: Float64) raises -> Float64:
        """Return the nonnegative extent below the baseline in logical units."""
        return self.height(font_size) * 0.2

    def additive_graphemes(self) -> Bool:
        """Opt into linear prefix sums only when grapheme widths are additive."""
        return False

    def nominal_glyphs(self) -> Bool:
        """Whether the encoder must disable kerning and optional ligatures."""
        return False

    def validate_family(self, family: StringSlice) raises:
        ...

    def width(self, text: StringSlice, font_size: Float64) raises -> Float64:
        ...

    def height(self, font_size: Float64) raises -> Float64:
        ...


struct FallbackTextMetrics(TextMetrics):
    """Deterministic font-independent estimates; no font I/O or dependency."""

    def __init__(out self):
        pass

    def font_weight(self) -> Optional[Int]:
        """Absence preserves the fallback role hierarchy and estimated anchors."""
        return None

    def additive_graphemes(self) -> Bool:
        return True

    def validate_family(self, family: StringSlice) raises:
        pass

    def width(self, text: StringSlice, font_size: Float64) raises -> Float64:
        return text_width(text, font_size)

    def height(self, font_size: Float64) raises -> Float64:
        return text_height(font_size)


def _measure_text[
    M: TextMetrics
](metrics: M, text: StringSlice, font_size: Float64) raises -> Float64:
    var width = metrics.width(text, font_size)
    if not isfinite(width) or width < 0.0:
        raise Error("text metrics width must be finite and nonnegative; got ", width)
    return width


def _measure_height[M: TextMetrics](metrics: M, font_size: Float64) raises -> Float64:
    var height = metrics.height(font_size)
    if not isfinite(height) or height <= 0.0:
        raise Error("text metrics height must be finite and positive; got ", height)
    return height


def _measure_ascent[M: TextMetrics](metrics: M, font_size: Float64) raises -> Float64:
    var extent = metrics.ascent(font_size)
    if not isfinite(extent) or extent < 0.0:
        raise Error("text metrics ascent must be finite and nonnegative; got ", extent)
    return extent


def _measure_descent[M: TextMetrics](metrics: M, font_size: Float64) raises -> Float64:
    var extent = metrics.descent(font_size)
    if not isfinite(extent) or extent < 0.0:
        raise Error("text metrics descent must be finite and nonnegative; got ", extent)
    return extent
