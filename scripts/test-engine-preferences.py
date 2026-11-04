#!/usr/bin/env python3
"""Exercise the real compiled Astrolog bridge; runs on Linux and macOS."""
import datetime
import json
import math
import os
from pathlib import Path
import struct
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
ENGINE = ROOT / 'Engine/bin/astrolog'
RESOURCES = ROOT / 'Upstream/Astrolog'
BASE = ['-qb','1','1','2000','12:00','0','0','0','0','-c','0','=b','_k','_k0','_s']
ENV = {**os.environ, 'ASTROLOG':'.:./ephem', 'LC_ALL':'C'}
CHECKS = []

def execute(args, graphics=False):
    safe = ['-0n~' if graphics else '-0on~','-YQ','0']
    if args[:1] == ['--json']:
        args = args[:1] + safe + args[1:]
    else:
        args = safe + args
    result = subprocess.run([str(ENGINE), *args], cwd=RESOURCES, env=ENV,
                            capture_output=True, text=True, timeout=40)
    assert result.returncode == 0, (result.returncode, result.stderr[:300], result.stdout[:200])
    return result.stdout

def preferences(objects, aspects, keep_principal=False):
    ids = sorted(set(objects) | (set(range(1,11)) if keep_principal else set()))
    return (['=u8' if 74 in ids else '_u8', '-R0', *map(str,ids),
             '-RT0', *map(str,ids), '-RA0', *map(str, sorted(aspects))])

def chart(objects, aspects):
    raw = execute(['--json', *BASE, *preferences(objects, aspects, True)])
    return json.loads(raw[raw.index('{'):raw.rindex('}')+1])

def angular_distance(a, b):
    d = abs(a-b) % 360
    return min(d, 360-d)

def invariant(c):
    by_id = {p['id']:p for p in c['positions']}
    assert len(by_id) == len(c['positions'])
    assert len(c['houseCusps']) == 12
    assert set(by_id).isdisjoint(c['unavailableObjects'])
    assert all(math.isfinite(p['longitude']) and 0 <= p['longitude'] < 360 for p in by_id.values())
    for aspect in c['aspects']:
        a = by_id[aspect['first']]['longitude']; b = by_id[aspect['second']]['longitude']
        assert abs(abs(angular_distance(a,b)-aspect['angle'])-abs(aspect['orb'])) < 1e-6

selection = list(range(1,22)) + [74]
all_aspects = list(range(1,25))
c = chart(selection, all_aspects)
invariant(c)
by_id = {p['id']:p for p in c['positions']}
assert 16 in by_id and 17 in by_id
assert abs(angular_distance(by_id[16]['longitude'],by_id[17]['longitude'])-180) < 1e-7
CHECKS.append('Both lunar nodes are available and exactly opposite')
assert 74 in by_id or 74 in c['unavailableObjects']
CHECKS.append('Charon either has ephemeris data or is explicitly unavailable; no fabricated point')
for kind in all_aspects:
    single = chart(selection, [kind]); invariant(single)
    assert all(a['kind']==kind for a in single['aspects'])
assert not chart(selection, [])['aspects']
CHECKS.append('All 24 major/minor aspect switches, disable-all, and angular orbs')
# Independent native text output confirms actual restrictions in both chart rings.
text = execute(BASE + preferences([1,2,16,17], [1,2,3,4,5]) + ['-v'])
assert 'Sun' in text and 'Moo' in text and 'Sou' in text and 'Jupi:' not in text
CHECKS.append('Textual positions obey selected objects')
second = ['-qb2','6','1','2000','12:00','0','-3','-37.6173','55.7558']
synastry = execute(BASE + preferences(selection,all_aspects) + second + ['-r0','nul','nul','-a','-g'])
assert len(synastry)>100
CHECKS.append('Synastry runs with selected objects and aspects')
presets = {'natal':['-v'], 'biwheel':['-v'], 'composite':['-v'], 'aspectGrid':['-g'],
           'astrocartography':['-L'], 'sphere':['-XX'], 'horizon':['-Z'], 'orbit':['-S'],
           'globe':['-XG'], 'ephemeris':['-E'], 'calendar':['-K']}
with tempfile.TemporaryDirectory(prefix='astraglass-preferences-') as tmp:
    for name, opts in presets.items():
        extra = second + ['-rc' if name=='composite' else '-r0','nul','nul'] if name in ('biwheel','composite') else []
        destination = Path(tmp)/f'{name}.bmp'
        execute(BASE + preferences(list(range(1,11))+[16,17],all_aspects) + extra + opts +
                ['-Xw','600','500','=Xr','-Xs','200','-Xbb','-Xo',str(destination)], graphics=True)
        bitmap = destination.read_bytes()
        assert bitmap[:2]==b'BM' and len(bitmap)>1000
        width,height = struct.unpack_from('<ii',bitmap,18)
        assert width>0 and height!=0
CHECKS.append('All eleven graphics modes produce nonempty valid-size BMPs with preferences')
report = {'passed':len(CHECKS), 'failed':0, 'checks':CHECKS, 'engine':c['engine'],
          'platform':os.uname().sysname, 'scope':'Actual C++ engine; does not validate macOS SwiftUI or Swift adapter',
          'unavailable_objects':c['unavailableObjects'], 'timestamp':datetime.datetime.now(datetime.timezone.utc).isoformat()}
print(json.dumps(report,ensure_ascii=False,indent=2))
