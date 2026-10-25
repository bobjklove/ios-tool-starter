#!/usr/bin/env python3
"""Keep XcodeGen target identifiers in the local StoreKit test plan after renaming."""
import json
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parents[1]
projects = list(root.glob('*.xcodeproj'))
if len(projects) != 1:
    raise SystemExit('Expected exactly one generated Xcode project')
project = projects[0]
payload = json.loads(subprocess.check_output(['plutil', '-convert', 'json', '-o', '-', str(project / 'project.pbxproj')]))
objects = payload['objects']
targets = {value['name']: key for key, value in objects.items() if value.get('isa') == 'PBXNativeTarget'}
app = project.stem
plan = root / (app + '.xctestplan')
content = json.loads(plan.read_text())
reference = lambda name: {'containerPath': 'container:' + project.name, 'identifier': targets[name], 'name': name}
content['defaultOptions']['targetForVariableExpansion'] = reference(app)
content['testTargets'] = [{'parallelizable': False, 'target': reference(app + 'Tests')}]
plan.write_text(json.dumps(content, indent=2) + '\n')
