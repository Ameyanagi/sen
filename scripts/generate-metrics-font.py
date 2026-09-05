"""Rebuild the original MIT/Apache-2.0 Sen font fixture with fonttools 4.61.1.

pixi exec --spec fonttools==4.61.1 -- python scripts/generate-metrics-font.py
The deliberately small glyph set makes missing-glyph failures reproducible.
"""
from pathlib import Path
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.feaLib.builder import addOpenTypeFeaturesFromString
from copy import deepcopy

patterns = {
    'A': ['01110','10001','10001','11111','10001','10001','10001'],
    'W': ['10001','10001','10001','10101','10101','10101','01010'],
    'M': ['10001','11011','10101','10101','10001','10001','10001'],
    'I': ['11111','00100','00100','00100','00100','00100','11111'],
    '0': ['01110','10011','10101','10101','11001','10001','01110'],
    '1': ['00100','01100','00100','00100','00100','00100','01110'],
    '2': ['01110','10001','00001','00010','00100','01000','11111'],
    '3': ['11110','00001','00001','01110','00001','00001','11110'],
    '4': ['00010','00110','01010','10010','11111','00010','00010'],
    '5': ['11111','10000','10000','11110','00001','00001','11110'],
    '6': ['01110','10000','10000','11110','10001','10001','01110'],
    '7': ['11111','00001','00010','00100','01000','01000','01000'],
    '8': ['01110','10001','10001','01110','10001','10001','01110'],
    '9': ['01110','10001','10001','01111','00001','00001','01110'],
    '日': ['11111','10001','10001','11111','10001','10001','11111'],
    '本': ['00100','11111','00100','01110','10101','00100','01110'],
    '語': ['11111','00010','11111','10101','11111','10101','11111'],
    '.': ['00000']*6+['00100'],
    '…': ['00000']*6+['10101'],
    '-': ['00000']*3+['11111']+['00000']*3,
    ' ': ['00000']*7,
}
chars = sorted(patterns)
order = ['.notdef'] + ['u%04X'%ord(c) for c in chars]
font = FontBuilder(1000, isTTF=True)
font.setupGlyphOrder(order)
font.setupCharacterMap({ord(c): 'u%04X'%ord(c) for c in chars})
glyphs, metrics = {}, {}
for char, name in [('A', '.notdef')] + [(c,'u%04X'%ord(c)) for c in chars]:
    width = 1000 if ord(char)>127 and char!='…' else {'W':950,'M':850,'I':350,' ':300}.get(char,650)
    pen = TTGlyphPen(None)
    for row, line in enumerate(patterns[char]):
        for col, value in enumerate(line):
            if value == '1':
                left = 40 + col*(width-80)/5
                right = 40 + (col+1)*(width-80)/5
                top, bottom = 700-row*100, 600-row*100
                pen.moveTo((left,bottom)); pen.lineTo((right,bottom))
                pen.lineTo((right,top)); pen.lineTo((left,top)); pen.closePath()
    glyphs[name]=pen.glyph(); metrics[name]=(width,40 if char!=' ' else 0)
font.setupGlyf(glyphs)
font.setupHorizontalMetrics(metrics)
font.setupHorizontalHeader(ascent=800, descent=-200, lineGap=100)
font.setupOS2(sTypoAscender=800,sTypoDescender=-200,sTypoLineGap=100,usWinAscent=800,usWinDescent=200)
font.setupNameTable({'familyName':'Sen Metrics Fixture','styleName':'Regular','uniqueFontIdentifier':'SenMetricsFixture-1','fullName':'Sen Metrics Fixture','psName':'SenMetricsFixture','version':'Version 1.0'})
font.setupPost(); font.setupMaxp()
font.font['head'].created=font.font['head'].modified=2082844800
font.font.recalcTimestamp=False
# A default locl feature deliberately changes A's advance. Nominal rendering
# must disable it, not merely turn off kerning/ligatures.
addOpenTypeFeaturesFromString(font.font, """
languagesystem DFLT dflt;
languagesystem latn dflt;
feature locl { sub u0041 by u0057; } locl;
""")
font.save('tests/fixtures/metrics.ttf')
wide = deepcopy(font.font)
wide['OS/2'].usWeightClass = 600
for name,(advance,bearing) in wide['hmtx'].metrics.items():
    wide['hmtx'].metrics[name] = (advance*2,bearing)
wide.save('tests/fixtures/metrics-semibold.ttf')
deep = deepcopy(font.font)
glyph = deep['glyf']['u004D']
for index,(x,y) in enumerate(glyph.coordinates):
    glyph.coordinates[index] = (x, round(-1500+y*3600/700))
deep['hhea'].ascent = deep['OS/2'].sTypoAscender = deep['OS/2'].usWinAscent = 2200
deep['hhea'].descent = deep['OS/2'].sTypoDescender = -1600
deep['OS/2'].usWinDescent = 1600
deep.save('tests/fixtures/metrics-deep.ttf')
