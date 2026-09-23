"""Validate the deliverable and create an isolated project from its actual assets."""
from pathlib import Path
import hashlib
import json
import zipfile
import sys

root = Path(__file__).resolve().parent.parent
if len(sys.argv) != 2 or Path(sys.argv[1]).name != sys.argv[1]:
    raise SystemExit('Pass the APK filename from builds/ explicitly.')
apk = root / 'builds' / sys.argv[1]
extracted = root / 'artifacts' / (apk.stem + '-smoke')
with zipfile.ZipFile(apk) as package:
    assert package.testzip() is None, 'Corrupt APK entry'
    names = package.namelist()
    for database in (root / 'data').glob('*.json'):
        path = 'assets/data/' + database.name
        assert path in names, 'Missing database: ' + database.name
        assert json.loads(package.read(path)) == json.loads(database.read_text(encoding='utf-8-sig')), 'Database not current: ' + database.name
    for script in (root / 'scripts').glob('*.gd'):
        assert 'assets/scripts/' + script.stem + '.gdc' in names, 'Missing game script: ' + script.name
    for retired in ['planet_worlds', 'planet_panel', 'planet_view', 'planet_modern']:
        assert 'assets/scripts/' + retired + '.gdc' not in names, 'Retired gameplay was repackaged: ' + retired
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
(root / 'artifacts' / (apk.stem + '-audit.json')).write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps(report, ensure_ascii=False, indent=2))
