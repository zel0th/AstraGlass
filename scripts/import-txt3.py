#!/usr/bin/env python3
"""Index a privately supplied ZET/Txt3 directory without publishing its texts.
Only documented natal section codes are bound to chart positions. All other
sections remain searchable with their original source and section identifier.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re

PLANETS = {str(i): i for i in range(1, 11)}
PLANETS.update({'11': 16, '12': 17, '13': 18, 'CHI': 11,
                'A1': 12, 'A2': 13, 'A3': 14, 'A4': 15, 'FOR': 19,
                'SO': 1, 'SU': 1, 'MO': 2, 'ME': 3, 'VE': 4, 'MA': 5,
                'JU': 6, 'SA': 7, 'UR': 8, 'NE': 9, 'PL': 10})
SIGNS = {s: i for i, s in enumerate(['AR','TA','GE','CN','LE','VI','LI','SC','SG','CP','AQ','PI'])}
SIGNS.update({'CA': 3, 'SA': 8})
ANGLES = {1: 0, 2: 30, 3: 36, 4: 40, 5: 45, 6: 60, 7: 72,
          8: 90, 9: 108, 10: 120, 11: 135, 12: 144, 13: 150, 14: 180}
CATEGORIES = {'PS':'Планеты', 'PH':'Планеты', 'P':'Планеты', 'S':'Знаки', 'H':'Дома', 'HS':'Дома', 'AP':'Аспекты'}
HEADER = re.compile(r'^\[([^]\n]+)\][ \t]*(.*)$', re.M)


def number(code):
    return int(code.strip()) if code.strip().isdigit() else None


def planet(code):
    key = str(number(code)) if number(code) is not None else code.strip().upper()
    return PLANETS.get(key)


def sign(code):
    n = number(code)
    return n - 1 if n is not None and 1 <= n <= 12 else SIGNS.get(code.strip().upper())


def house(code):
    n = number(code)
    if n is not None and 101 <= n <= 112: n -= 100
    return n if n is not None and 1 <= n <= 12 else None


def bindings(kind, code):
    parts = [x.strip() for x in code.split('.')]
    keys, planets, signs, houses, angles = [], [], [], [], []
    # Multi-value selectors apply to each listed member; unsupported expressions
    # are deliberately not guessed. Non-natal types never reach these branches.
    if kind in ('PS', 'PH', 'HS') and len(parts) == 2:
        for left in parts[0].split(','):
            for right in parts[1].split(','):
                a = house(left) if kind == 'HS' else planet(left)
                b = house(right) if kind == 'PH' else sign(right)
                if a is None or b is None: continue
                prefix = {'PS':'planet-sign','PH':'planet-house','HS':'house-sign'}[kind]
                keys.append(f'{prefix}:{a}:{b}')
                (houses if kind == 'HS' else planets).append(a)
                (houses if kind == 'PH' else signs).append(b)
    elif kind in ('P','S','H') and len(parts) == 1:
        for part in parts[0].split(','):
            value = {'P': planet, 'S': sign, 'H': house}[kind](part)
            if value is not None:
                keys.append(f'{ {"P":"planet","S":"sign","H":"house"}[kind]}:{value}')
                {'P':planets,'S':signs,'H':houses}[kind].append(value)
    elif kind == 'AP' and len(parts) == 3:
        a, b = planet(parts[0]), planet(parts[2])
        if a is not None and b is not None and a != b:
            for token in parts[1].split(','):
                token = token.strip(); n = number(token)
                if n is None: continue
                # Three digits denote degrees; short numbers 1...14 are ZET IDs.
                angle = n if len(token) == 3 or n > 14 or n == 0 else ANGLES.get(n)
                if angle not in set(ANGLES.values()): continue
                keys.append(f'aspect-pair:{angle}:{min(a,b)}:{max(a,b)}')
                planets.extend([a,b]); angles.append(angle)
    return dict(bindings=sorted(set(keys)), planetIDs=sorted(set(planets)),
                signIndices=sorted(set(signs)), houseNumbers=sorted(set(houses)),
                aspectAngle=angles[0] if len(set(angles)) == 1 else None)


def decode(raw):
    try: return raw.decode('utf-8-sig')
    except UnicodeDecodeError: return raw.decode('cp1251')


def convert(directory):
    sources, records = [], []
    for file in sorted(Path(directory).rglob('*')):
        if not file.is_file(): continue
        raw = file.read_bytes(); text = decode(raw).replace('\r\n', '\n').replace('\r', '\n')
        checksum = hashlib.sha256(raw).hexdigest()
        relative = str(file.relative_to(directory))
        comments = re.findall(r'^//\s*(.*)$', text, re.M)
        kind_match = re.match(r'(\w+)\b', comments[0]) if comments else None
        kind = kind_match[1] if kind_match else ''
        source_title = comments[1].strip() if len(comments) > 1 and comments[1].strip() else file.stem
        source_id = hashlib.sha256(relative.encode()).hexdigest()[:20]
        matches = list(HEADER.finditer(text)); count = 0
        sections = [(m[1],m[2].strip(),m.start(),m.end(),matches[i+1].start() if i+1<len(matches) else len(text)) for i,m in enumerate(matches)]
        if not sections: sections = [('',source_title,0,0,len(text))]
        for code, title, start, body_start, end in sections:
            body = text[body_start:end].strip()
            # Keep the author's original text, including comments within a section.
            if not body: continue
            title = title or (f'{source_title} · [{code}]' if code else source_title)
            metadata = bindings(kind,code)
            category = CATEGORIES.get(kind,'Справочник')
            records.append(dict(id=f'txt3-{source_id}-{start}', title=title,
                originalTitle=title, category=category, body=body,
                source=relative, sourceTitle=source_title, sourceSHA256=checksum,
                paragraphStart=text.count('\n',0,start)+1,
                paragraphEnd=text.count('\n',0,end)+1, headingLevel=1,
                breadcrumbs=[source_title, f'[{code}]'] if code else [source_title],
                keywords=[kind,code,source_title], **metadata))
            count += 1
        sources.append(dict(id=source_id,fileName=relative,title=source_title,
                            sha256=checksum,sectionCount=count))
    return dict(schemaVersion=1,sources=sources,records=records)


if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory',type=Path);parser.add_argument('output',type=Path)
    args=parser.parse_args(); corpus=convert(args.directory)
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(corpus,ensure_ascii=False,separators=(',',':')),encoding='utf-8')
    print(f'{len(corpus["sources"])} sources, {len(corpus["records"])} sections, '
          f'{sum(bool(r["bindings"]) for r in corpus["records"])} natal sections; {args.output.stat().st_size:,} bytes')
