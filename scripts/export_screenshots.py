"""Export the two retained UI screenshots without re-running the tests (Xcode 15)."""
import json
from pathlib import Path
import subprocess
import sys

result = Path(sys.argv[1])
output = Path(sys.argv[2])
output.mkdir(parents=True, exist_ok=True)
visited = set()
exported = set()


def scalar(value):
    return value.get('_value') if isinstance(value, dict) else value


def load(identifier=None):
    args = ['xcrun', 'xcresulttool', 'get', '--path', str(result), '--format', 'json']
    if identifier:
        args += ['--id', identifier]
    return json.loads(subprocess.check_output(args))


def walk(node):
    if isinstance(node, list):
        for item in node:
            walk(item)
    elif isinstance(node, dict):
        name = scalar(node.get('name')) or ''
        payload = node.get('payloadRef', {})
        identifier = scalar(payload.get('id'))
        if identifier and name.startswith(('01-Fjarr', '02-Installningar')) and identifier not in exported:
            destination = output / (name.split('.')[0] + '.png')
            subprocess.run(['xcrun', 'xcresulttool', 'export', '--type', 'file', '--path', str(result),
                            '--id', identifier, '--output-path', str(destination)], check=True)
            exported.add(identifier)
            print(destination)
        for key, value in node.items():
            if key in ('testsRef', 'summaryRef') and isinstance(value, dict):
                ref = scalar(value.get('id'))
                if ref and ref not in visited:
                    visited.add(ref)
                    walk(load(ref))
            else:
                walk(value)


walk(load())
if len(exported) != 2:
    raise SystemExit(f'Expected two named screenshots, exported {len(exported)}')
