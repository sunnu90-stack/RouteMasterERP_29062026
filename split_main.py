#!/usr/bin/env python3
"""
Route Master ERP - main.dart splitter
Place this script AND main_v23_8.dart in your ROUTE-MASTER-ERP folder
(same level as pubspec.yaml and the lib folder), then run:

    python split_main.py
"""

import os, sys

# ── Find the source file ──────────────────────────────────────────────────────
CANDIDATES = [
    'main_v23_8.dart',                          # placed next to this script
    os.path.join('lib', 'main_v23_8.dart'),
    os.path.join('lib', 'main.dart'),
]

src_path = None
for c in CANDIDATES:
    if os.path.exists(c):
        with open(c, 'r', encoding='utf-8') as f:
            content = f.read()
        if 'class AppConfig' in content and 'class FirebaseService' in content and len(content) > 500000:
            src_path = c
            break

if src_path is None:
    print("ERROR: Could not find the original monolith (main_v23_8.dart).")
    print("Make sure main_v23_8.dart is in the same folder as this script.")
    sys.exit(1)

with open(src_path, 'r', encoding='utf-8') as f:
    all_lines = f.readlines()

print(f"Found source: {src_path} ({len(all_lines):,} lines)")

# ── Split plan ────────────────────────────────────────────────────────────────
PLAN = [
    ('config.dart',          76,    262),
    ('firebase_service.dart',263,   1069),
    ('enums.dart',           1070,  1104),
    ('models.dart',          1105,  3057),
    ('engines.dart',         3058,  3898),
    ('ai.dart',              3899,  6610),
    ('app.dart',             6611,  6813),
    ('auth_screens.dart',    6814,  8348),
    ('main_shell.dart',      8349,  19787),
    ('search_fields.dart',   19788, 20309),
    ('feature_screens.dart', 20310, 26964),
    ('painters.dart',        26965, len(all_lines)),
]

PART_DIRECTIVES = [
    "part 'src/config.dart';",
    "part 'src/firebase_service.dart';",
    "part 'src/enums.dart';",
    "part 'src/models.dart';",
    "part 'src/engines.dart';",
    "part 'src/ai.dart';",
    "part 'src/app.dart';",
    "part 'src/auth_screens.dart';",
    "part 'src/main_shell.dart';",
    "part 'src/search_fields.dart';",
    "part 'src/feature_screens.dart';",
    "part 'src/painters.dart';",
]

# ── Create lib/src/ ───────────────────────────────────────────────────────────
src_dir = os.path.join('lib', 'src')
os.makedirs(src_dir, exist_ok=True)
print(f"Directory ready: {src_dir}\n")

# ── Write each part file ──────────────────────────────────────────────────────
for fname, start, end in PLAN:
    body = all_lines[start - 1 : end]
    out  = "// ============================================================\n"
    out += f"// {fname}  --  part of liquid_logistics main library\n"
    out += f"// Extracted from original monolith (lines {start}-{end})\n"
    out += "// DO NOT add imports here -- all imports live in main.dart\n"
    out += "// ============================================================\n"
    out += "part of 'main.dart';\n"
    out += "\n"
    out += "".join(body)

    out_path = os.path.join(src_dir, fname)
    with open(out_path, 'w', encoding='utf-8', newline='\n') as wf:
        wf.write(out)
    print(f"  wrote src/{fname:30s}  {os.path.getsize(out_path):>8,} bytes  ({len(body):>5} lines)")

# ── Write new main.dart ───────────────────────────────────────────────────────
header = all_lines[0:74]

parts_block  = "\n// ============================================================\n"
parts_block += "// PART FILES -- split from original monolith by feature area\n"
parts_block += "// All files share this library's imports and private scope.\n"
parts_block += "// ============================================================\n"
for p in PART_DIRECTIVES:
    parts_block += p + "\n"

main_path = os.path.join('lib', 'main.dart')
with open(main_path, 'w', encoding='utf-8', newline='\n') as wf:
    wf.writelines(header)
    wf.write(parts_block)

print(f"\n  wrote lib/main.dart  ({os.path.getsize(main_path):,} bytes, 92 lines)")

# ── Verify every file ─────────────────────────────────────────────────────────
print("\n=== VERIFICATION ===")
all_ok = True

with open(main_path, 'r', encoding='utf-8') as f:
    mc = f.read()
missing = [p for p in PART_DIRECTIVES if p not in mc]
if missing:
    for m in missing:
        print(f"  FAIL main.dart missing: {m}")
    all_ok = False
else:
    print(f"  OK   lib/main.dart -- all 12 part directives present")

for fname, _, _ in PLAN:
    path = os.path.join(src_dir, fname)
    with open(path, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    line6 = lines[5].rstrip() if len(lines) > 5 else "MISSING"
    if line6 != "part of 'main.dart';":
        print(f"  FAIL src/{fname} -- line 6 is: {repr(line6)}")
        all_ok = False
    else:
        print(f"  OK   src/{fname:30s}  {os.path.getsize(path):>8,} bytes")

print()
if all_ok:
    print("=" * 50)
    print("  SUCCESS - all files written and verified.")
    print("=" * 50)
    print()
    print("Next steps:")
    print("  flutter pub get")
    print("  flutter run -d chrome")
else:
    print("ERRORS found -- check output above before running Flutter.")
