"""Validate the deliverable and create an isolated project from its actual assets."""
from pathlib import Path
import hashlib
import json
import zipfile
import sys

root = Path(__file__).resolve().parent.parent
apk = root / 'builds' / (sys.argv[1] if len(sys.argv) > 1 else 'AtomAtelier-0.11.0-android.apk')
extracted = root / 'artifacts' / (apk.stem + '-smoke')
with zipfile.ZipFile(apk) as package:
    assert package.testzip() is None, 'Corrupt APK entry'
    names = package.namelist()
    for database in ['materials', 'elements', 'economy', 'baselines', 'campus_people', 'campus_buildings', 'island_balance', 'planet_balance']:
        path = f'data/{database}.json'
        assert 'assets/' + path in names, 'Missing database: ' + database
        assert json.loads(package.read('assets/' + path)) == json.loads((root / path).read_text(encoding='utf-8')), 'Database not current: ' + database
    for script in ['main', 'ui', 'lab_state', 'atom_editor', 'world_view', 'economy', 'specimen', 'structure_sandbox', 'sandbox_editor', 'sandbox_reference', 'science_pipeline', 'science_jobs', 'science_chart', 'campus_sim', 'campus_payroll', 'campus_layout', 'campus_view', 'campus_panel', 'island_storage', 'island_logistics', 'island_market', 'island_panel', 'island_guest', 'order_bubbles', 'building_drag', 'campus_architecture', 'static_geometry', 'planet_program', 'planet_worlds', 'planet_view', 'planet_panel']:
        assert 'assets/scripts/' + script + '.gdc' in names, 'Missing game script: ' + script
    assert any('NotoSansCJKsc-Regular' in n for n in names), 'Missing Chinese font'
    assert 'assets/assets/fonts/OFL.txt' in names, 'Missing font license'
    assert 'assets/assets/licenses/Godot-MIT.txt' in names, 'Missing Godot license'
    forbidden = [n for n in names if n.startswith(('assets/tools/', 'assets/saves/', 'assets/artifacts/', 'assets/.runtime/', 'assets/tests/')) or n.endswith(('.keystore', '.ps1', '.cmd'))]
    assert not forbidden, forbidden
    natives = sorted(n for n in names if n.endswith('libgodot_android.so'))
    assert natives == ['lib/arm64-v8a/libgodot_android.so', 'lib/armeabi-v7a/libgodot_android.so'], natives
    for name in names:
        if not name.startswith('assets/') or name.endswith('/'):
            continue
        destination = (extracted / name[7:]).resolve()
        assert destination.is_relative_to(extracted.resolve()), 'Unsafe archive path'
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(package.read(name))
(extracted / 'artifacts').mkdir(exist_ok=True)
(extracted / 'saves').mkdir(exist_ok=True)
report = {
    'apk': apk.name,
    'size_bytes': apk.stat().st_size,
    'sha256': hashlib.sha256(apk.read_bytes()).hexdigest(),
    'zip_integrity': 'PASS',
    'materials_match': 'PASS',
    'scripts_and_chinese_font': 'PASS',
    'private_file_exclusion': 'PASS',
    'native_libraries': natives,
    'physical_device_test': 'not performed',
}
(root / 'artifacts/apk-audit.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps(report, ensure_ascii=False, indent=2))
