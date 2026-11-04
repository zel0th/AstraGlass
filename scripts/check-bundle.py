#!/usr/bin/env python3
"""Validate the installed bundle, including helper execution after relocation."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

app = Path(sys.argv[1]).resolve()
resources = app / 'Contents/Resources'
helper = app / 'Contents/Helpers/astrolog'
assert not (resources / 'interpretations-txt3.json').exists(), 'Retired Txt3 corpus must not ship'
assert helper.is_file() and os.access(helper, os.X_OK), 'Astrolog helper must be executable'
assert os.access(app / 'Contents/MacOS/AstraGlass', os.X_OK), 'App must be executable'
for name in ['Engine/atlas.as', 'Engine/timezone.as', 'Engine/astrolog.as',
             'Fonts/AstraGlassAstrology.ttf', 'Fonts/LICENSE-Astronomicon.txt', 'Fonts/DejaVuSans.ttf', 'Fonts/LICENSE-DejaVu.txt',
             'en.lproj/Localizable.strings', 'ru.lproj/Localizable.strings']:
    assert (resources / name).is_file(), 'Missing resource: ' + name

with tempfile.TemporaryDirectory(prefix='AstraGlass relocated ') as folder:
    relocated = Path(folder) / 'AstraGlass.app'
    shutil.copytree(app, relocated)
    engine = relocated / 'Contents/Helpers/astrolog'
    env = dict(os.environ, ASTROLOG=str(relocated / 'Contents/Resources/Engine'))
    args = ['-qb', '1', '1', '2000', '12:00', '0', '-3', '-37.6173', '55.7558', '_k', '_k0']
    result = subprocess.run([str(engine), '--json', *args], cwd=folder, env=env,
                            capture_output=True, text=True, timeout=20, check=True)
    chart = json.loads(result.stdout[result.stdout.index('{'):result.stdout.rindex('}') + 1])
    assert len(chart['positions']) >= 10 and len(chart['houseCusps']) == 12
    second = ['-qb2', '6', '1', '2000', '12:00', '0', '-3', '-37.6173', '55.7558']
    report = subprocess.run([str(engine), *args, *second, '-r0', 'nul', 'nul', '-a'],
                            cwd=folder, env=env, capture_output=True, timeout=30, check=True)
    assert len(report.stdout) > 100, 'Empty synastry report'
    bitmap = Path(folder) / 'relocated.bmp'
    subprocess.run([str(engine), *args, '-v', '-Xw', '600', '600', '-Xbb', '-Xo', str(bitmap)],
                   cwd=folder, env=env, capture_output=True, timeout=40, check=True)
    assert bitmap.read_bytes()[:2] == b'BM', 'Invalid graphics output'
print('Bundle verified: resources, executable permissions, relocated natal/synastry/graphics')
