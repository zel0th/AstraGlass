#!/usr/bin/env python3
"""Import the owner's Podvodny DOCX books into AstraGlass's private text index.

Uses only the Python standard library; never downloads or invents book text.
Accepts a ZIP of DOCX files, a directory, or one DOCX. Original text is retained.
"""
import argparse
import hashlib
import io
import json
import re
import sys
import zipfile
from collections import Counter
from pathlib import Path
from xml.etree import ElementTree as ET

W = '{http://schemas.openxmlformats.org/wordprocessingml/2006/main}'
PLANETS = [(1, 'солнц'), (2, 'лун'), (3, 'меркур'), (4, 'венер'),
           (5, 'марс'), (6, 'юпитер'), (7, 'сатурн'), (8, 'уран'),
           (9, 'нептун'), (10, 'плутон'), (11, 'хирон')]
SIGNS = ['овен|овна|овне', 'телец|тельца|тельце', 'близнецы|близнецов|близнецах',
         'рак|рака|раке', 'лев|льва|льве', 'дева|девы|деве', 'весы|весов|весах',
         'скорпион|скорпиона|скорпионе', 'стрелец|стрельца|стрельце',
         'козерог|козерога|козероге', 'водолей|водолея|водолее', 'рыбы|рыб|рыбах']
HOUSES = ['перв', 'втор', 'трет', 'четверт', 'пят', 'шест', 'седьм',
          'восьм', 'девят', 'десят', 'одиннадцат', 'двенадцат']
ASPECTS = [('полутораквадрат', 135), ('полуквадрат', 45), ('полусекстиль', 30),
           ('биквинтиль', 144), ('тридециль', 108), ('соединен', 0),
           ('оппозиц', 180), ('секстил', 60), ('квадрат', 90), ('трин', 120),
           ('децил', 36), ('квинтил', 72), ('квиконс', 150)]


def fixed_filename(name):
    try:
        return name.encode('cp437').decode('utf-8')
    except (UnicodeEncodeError, UnicodeDecodeError):
        return name


def read_inputs(path):
    if path.is_dir():
        for file in sorted(path.glob('*.docx')):
            yield file.name, file.read_bytes()
    elif path.suffix.lower() == '.docx':
        yield path.name, path.read_bytes()
    else:
        with zipfile.ZipFile(path) as archive:
            for info in sorted(archive.infolist(), key=lambda i: i.filename):
                if info.filename.startswith('__MACOSX/') or not info.filename.lower().endswith('.docx'):
                    continue
                if info.file_size > 50_000_000:
                    raise ValueError('DOCX exceeds the 50 MB import limit')
                yield Path(fixed_filename(info.filename)).name, archive.read(info)


def paragraph_text(element):
    parts = []
    for child in element.iter():
        if child.tag == W + 't':
            parts.append(child.text or '')
        elif child.tag == W + 'tab':
            parts.append('\t')
        elif child.tag in (W + 'br', W + 'cr'):
            parts.append('\n')
    return ''.join(parts).strip()


def blocks_from_docx(data):
    with zipfile.ZipFile(io.BytesIO(data)) as doc:
        if doc.getinfo('word/document.xml').file_size > 100_000_000:
            raise ValueError('Document XML exceeds the import limit')
        root = ET.fromstring(doc.read('word/document.xml'))
        body = root.find(W + 'body')
        for number, element in enumerate(body, 1):
            if element.tag == W + 'p':
                style = element.find('./' + W + 'pPr/' + W + 'pStyle')
                style = style.get(W + 'val', '') if style is not None else ''
                outline = element.find('./' + W + 'pPr/' + W + 'outlineLvl')
                heading = int(style) if style in ('1', '2', '3') else 0
                if not heading and style.lower().startswith('heading') and style[-1:].isdigit():
                    heading = int(style[-1])
                if outline is not None and int(outline.get(W + 'val', '9')) < 3:
                    heading = int(outline.get(W + 'val')) + 1
                yield number, heading, paragraph_text(element)
            elif element.tag == W + 'tbl':
                rows = []
                for row in element.findall(W + 'tr'):
                    rows.append('\t'.join(' / '.join(paragraph_text(p) for p in cell.findall(W + 'p'))
                                          for cell in row.findall(W + 'tc')))
                yield number, 0, '\n'.join(rows)


def normalize_title(title):
    # Layout-only repairs: Word has a line break between chapter number and name.
    title = re.sub(r'(?<=\d)(?=[А-ЯЁ])', ' · ', title)
    title = re.sub(r'(?<=[а-яё])(?=\d{4})', ' · ', title)
    return re.sub(r'\s+', ' ', title).strip()


def tags_for(title, category):
    t = title.lower().replace('ё', 'е')
    planets = [i for i, stem in PLANETS if re.search(r'\b' + stem, t)]
    # Lunar-node headings mention the Moon, but refer to the nodes rather than Moon position.
    if 'узл' in t or 'узел' in t:
        planets = [16, 17]
    signs = [i for i, stem in enumerate(SIGNS) if re.search(r'\b(?:' + stem + r')\b', t)]
    houses = []
    if 'дом' in t:
        houses = [i + 1 for i, stem in enumerate(HOUSES) if re.search(r'\b' + stem, t)]
    aspect = None
    if category == 'Аспекты':
        aspect = next((angle for stem, angle in ASPECTS if stem in t), None)
    return planets, signs, houses, aspect


def semantic_bindings(title, planets, signs, houses, angle):
    bindings = []
    if angle is not None:
        if not planets:
            bindings.append('aspect:' + str(angle))
        bindings.extend('aspect-planet:%s:%s' % (angle, planet) for planet in planets)
        return bindings
    if planets == [16, 17]:
        for node, prefix in [(16, 'северный'), (17, 'южный')]:
            match = re.search(prefix + r'\s+узел\s+в(?:о)?\s+([^—]+)', title.lower())
            if match:
                _, node_signs, node_houses, _ = tags_for(match.group(1) + (' дом' if 'доме' in match.group(1) else ''), '')
                bindings.extend('planet-sign:%s:%s' % (node, sign) for sign in node_signs)
                bindings.extend('planet-house:%s:%s' % (node, house) for house in node_houses)
            else:
                bindings.append('planet:' + str(node))
        return bindings
    if planets and signs:
        bindings.extend('planet-sign:%s:%s' % (planet, sign) for planet in planets for sign in signs)
    elif planets and houses:
        bindings.extend('planet-house:%s:%s' % (planet, house) for planet in planets for house in houses)
    elif houses and signs:
        bindings.extend('house-sign:%s:%s' % (house, sign) for house in houses for sign in signs)
    elif planets:
        bindings.extend('planet:' + str(planet) for planet in planets)
    elif houses:
        bindings.extend('house:' + str(house) for house in houses)
    elif signs:
        bindings.extend('sign:' + str(sign) for sign in signs)
    return bindings


def import_document(name, data):
    part = re.search(r'Часть\s*(\d)', name, re.I)
    part = int(part.group(1)) if part else 0
    category = {1: 'Знаки', 2: 'Планеты', 3: 'Дома', 4: 'Аспекты'}.get(part, 'Введение')
    source_hash = hashlib.sha256(data).hexdigest()
    source_title = 'Авессалом Подводный · Общая астрология' + (' · Часть ' + str(part) if part else '')
    records = []
    current = None
    hierarchy = {}

    def finish():
        if not current or not current['body']:
            return
        text = '\n\n'.join(current['body'])
        title = normalize_title(current['originalTitle'])
        planets, signs, houses, angle = tags_for(title, category)
        record_id = hashlib.sha256((name + ':' + str(current['paragraphStart']) + ':' + title).encode('utf-8')).hexdigest()[:20]
        records.append(dict(id=record_id, title=title, originalTitle=current['originalTitle'],
                            category=category, body=text, source=name, sourceTitle=source_title,
                            sourceSHA256=source_hash, paragraphStart=current['paragraphStart'],
                            paragraphEnd=current['paragraphEnd'], headingLevel=current['headingLevel'],
                            breadcrumbs=current['breadcrumbs'], keywords=[title, category] + current['breadcrumbs'],
                            planetIDs=planets, signIndices=signs, houseNumbers=houses, aspectAngle=angle,
                            bindings=semantic_bindings(title, planets, signs, houses, angle)))

    for number, level, text in blocks_from_docx(data):
        if not text:
            continue
        if level and text.lower().strip() == 'оглавление':
            break
        if level:
            finish()
            hierarchy = {k: v for k, v in hierarchy.items() if k < level}
            current = dict(originalTitle=text, body=[], paragraphStart=number,
                           paragraphEnd=number, headingLevel=level,
                           breadcrumbs=[hierarchy[k] for k in sorted(hierarchy)])
            hierarchy[level] = normalize_title(text)
        elif current:
            current['body'].append(text)
            current['paragraphEnd'] = number
    finish()
    return dict(id='part-' + str(part), fileName=name, title=source_title, sha256=source_hash,
                sectionCount=len(records)), records


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('input', type=Path, help='Archive, directory, or DOCX')
    parser.add_argument('--output', type=Path, default=Path('Resources/interpretations.json'))
    parser.add_argument('--preserve-docx', type=Path, help='Optional private source-copy directory')
    args = parser.parse_args()
    sources, records = [], []
    for name, data in read_inputs(args.input):
        source, sections = import_document(name, data)
        sources.append(source)
        records.extend(sections)
        if args.preserve_docx:
            args.preserve_docx.mkdir(parents=True, exist_ok=True)
            (args.preserve_docx / name).write_bytes(data)
    if not records:
        parser.error('No recognized text sections. Use DOCX files with Heading 1/2/3 styles.')
    corpus = dict(schemaVersion=1, author='Авессалом Подводный', language='ru',
                  sourcePolicy='Private user-supplied texts; no redistribution permission inferred.',
                  sources=sources, records=records)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(corpus, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(dict(output=str(args.output), sourceCount=len(sources), sectionCount=len(records),
                          byCategory=dict(Counter(r['category'] for r in records))), ensure_ascii=False))


if __name__ == '__main__':
    main()
