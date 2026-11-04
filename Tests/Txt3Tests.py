"""Synthetic importer checks contain no private author texts."""
import importlib.util
from pathlib import Path
import tempfile
spec=importlib.util.spec_from_file_location('txt3',Path(__file__).resolve().parents[1]/'scripts/import-txt3.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
assert m.bindings('PS','10.12')['bindings']==['planet-sign:10:11']
assert m.bindings('PS','11.01')['bindings']==['planet-sign:16:0']
assert m.bindings('PS','12.01')['bindings']==['planet-sign:17:0']
assert m.bindings('PH','CHI.03')['bindings']==['planet-house:11:3']
assert m.bindings('HS','101.12')['bindings']==['house-sign:1:11']
assert m.bindings('PS','A4.AQ')['bindings']==['planet-sign:15:10']
assert m.bindings('AP','10.14.01')['bindings']==['aspect-pair:180:1:10']
assert m.bindings('AP','01.060,120.02')['bindings']==['aspect-pair:120:1:2','aspect-pair:60:1:2']
assert m.bindings('AP','1.10.2')['bindings']==['aspect-pair:120:1:2']
assert m.bindings('AP','1.2.2')['bindings']==['aspect-pair:30:1:2']
assert not m.bindings('SNPP','01.000.02')['bindings']
assert not m.bindings('TR','01.000.02')['bindings']
assert not m.bindings('AP','SO.P^.MA')['bindings']
assert not m.bindings('PS','SEL.01')['bindings']
with tempfile.TemporaryDirectory() as folder:
    p=Path(folder)
    (p/'natal.txt').write_bytes('// PS Планеты\n// Автор\n[10.01] Плутон\nПолный текст'.encode('cp1251'))
    (p/'transit.txt').write_text('// TR Транзиты\n// Автор 2\n[01.000.02] Транзит\nТекст\nещё текст',encoding='utf-8')
    corpus=m.convert(p)
    assert len(corpus['sources'])==2 and len(corpus['records'])==2
    assert corpus['records'][0]['body']=='Полный текст'
    assert corpus['records'][1]['body']=='Текст\nещё текст' and not corpus['records'][1]['bindings']
print('Txt3 importer: 17 checks passed')
