#!/usr/bin/env python3
"""Build a Unicode astrology font from the bundled OFL Astronomicon outlines.

Rebuild only: python3 -m pip install fonttools; python3 scripts/build-symbol-font.py
Normal app builds use the committed TTF and require no Python font dependency.
ASCII and a few mathematical fallbacks come from bundled DejaVu Sans.
"""
from pathlib import Path
from fontTools.ttLib import TTFont
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.pens.transformPen import TransformPen

ROOT = Path(__file__).resolve().parents[1] / 'Resources/Fonts'
astro = TTFont(ROOT / 'Astronomicon.ttf')
base = TTFont(ROOT / 'DejaVuSans.ttf')
mapping = {chr(n): chr(ord('A') + n - 0x2648) for n in range(0x2648, 0x2654)}
mapping.update(dict(zip('♁☉☽☿♀♂♃♄♅♆♇⯓⚷⚳⚴⚵⚶☊☋⚸⊗', '>QRSTUVWXY_Zqlmnogiz?')))
mapping.update({'☌':'!', '☍':'"', '□':'#', '△':'$', '✶':'%', '℞':'N'})
outlines = {}; metrics = {}; cmap = {}

def add(code, font, character):
    source = font.getBestCmap()[ord(character)]
    name = 'u%04X' % code
    glyphs = font.getGlyphSet()
    scale = 1000 / font['head'].unitsPerEm
    pen = TTGlyphPen(None)
    # Decompose composites through the source glyph set before transformation.
    from fontTools.pens.recordingPen import DecomposingRecordingPen
    recording = DecomposingRecordingPen(glyphs)
    glyphs[source].draw(recording)
    recording.replay(TransformPen(pen, (scale, 0, 0, scale, 0, 0)))
    outlines[name] = pen.glyph()
    advance, lsb = font['hmtx'][source]
    metrics[name] = (round(advance * scale), round(lsb * scale))
    cmap[code] = name

for char in ''.join(chr(i) for i in range(32,127)) + '∠°′−':
    add(ord(char), base, char)
for char, original in mapping.items():
    add(ord(char), astro, original)
pen = TTGlyphPen(None); outlines['.notdef'] = pen.glyph(); metrics['.notdef'] = (600,0)
builder = FontBuilder(1000, isTTF=True)
builder.setupGlyphOrder(['.notdef'] + sorted(n for n in outlines if n != '.notdef'))
builder.setupCharacterMap(cmap); builder.setupGlyf(outlines); builder.setupHorizontalMetrics(metrics)
builder.setupHorizontalHeader(ascent=1100, descent=-300)
builder.setupNameTable({'familyName':'AstraGlass Astrology', 'styleName':'Regular',
    'uniqueFontIdentifier':'AstraGlassAstrology-1.0', 'fullName':'AstraGlass Astrology',
    'psName':'AstraGlassAstrology', 'version':'Version 1.0',
    'copyright':'Astronomicon outlines Copyright Roberto Corona, SIL OFL 1.1. ASCII from DejaVu Sans; see bundled licenses.',
    'licenseDescription':'SIL Open Font License 1.1; DejaVu/Bitstream notices also apply to ASCII outlines.'})
builder.setupOS2(sTypoAscender=1100, sTypoDescender=-300, usWinAscent=1100, usWinDescent=300)
builder.setupPost(); builder.setupMaxp()
builder.save(ROOT / 'AstraGlassAstrology.ttf')
print('AstraGlassAstrology.ttf:', len(cmap), 'glyphs; traditional Pluto U+2BD3 included')
