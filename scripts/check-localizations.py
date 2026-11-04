#!/usr/bin/env python3
"""Check bilingual label coverage without changing persistent values or source texts.

Run after UI changes. Explicit L10n.text(Russian, English) pairs are self-contained;
other static Russian labels need both bundled Localizable.strings entries.
Interpolated strings are reported separately for manual review, since their final
runtime values cannot be used as static localization keys.
"""
from pathlib import Path
import json
import re
import sys

ROOT = Path(__file__).resolve().parent.parent
STRING = r'"(?:[^"\\]|\\.)*"'
ENTRY = re.compile(r'(' + STRING + r')\s*=\s*(' + STRING + r')\s*;')
CYRILLIC = re.compile(r'[А-Яа-яЁё]')


def decode(value):
    try:
        return json.loads(value)
    except json.JSONDecodeError:
        return None  # A Swift interpolation, not a static catalog key.


def catalog(language):
    source = (ROOT / 'Resources' / f'{language}.lproj' / 'Localizable.strings').read_text()
    pairs = [(decode(key), decode(value)) for key, value in ENTRY.findall(source)]
    if len(pairs) != len({key for key, _ in pairs}):
        raise ValueError(f'Duplicate {language} localization keys')
    if any(key is None or not value for key, value in pairs):
        raise ValueError(f'Invalid or empty {language} localization entry')
    return dict(pairs)


ru, en = catalog('ru'), catalog('en')
missing = []
interpolated = []
files = sorted((ROOT / 'Sources' / 'AstraApp').glob('*.swift'))
files += [ROOT / 'Sources' / 'AstraCore' / 'AstrologEngine.swift']
for path in files:
    source = path.read_text()
    # Only literal/literal calls are removed; interpolated two-argument messages
    # remain in the manual-review list, where they are harmless and explicit.
    source = re.sub(r'L10n\.text\(\s*' + STRING + r'\s*,\s*' + STRING + r'\s*\)', '', source)
    for number, line in enumerate(source.splitlines(), 1):
        if line.lstrip().startswith('//'):
            continue
        for match in re.finditer(STRING, line):
            token = match.group()
            if not CYRILLIC.search(token):
                continue
            value = decode(token)
            location = f'{path.relative_to(ROOT)}:{number}'
            if value is None or '\\(' in token:
                interpolated.append({'location': location, 'text': token})
            elif value not in ru or value not in en:
                missing.append({'location': location, 'text': value})

result = {'catalog_keys': len(en), 'matching_language_keys': ru.keys() == en.keys(),
          'missing_static_labels': missing, 'interpolated_review_count': len(interpolated)}
if '--verbose' in sys.argv:
    result['interpolated_strings'] = interpolated
print(json.dumps(result, ensure_ascii=False, indent=2))
sys.exit(1 if missing or ru.keys() != en.keys() else 0)
