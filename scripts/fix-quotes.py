#!/usr/bin/env python3
"""Fix embedded quotes in the Chinese ARB translation file."""

import json
import re

ZH_PATH = r"D:\github\absorb\lib\l10n\app_zh.arb"

# Read the file
with open(ZH_PATH, 'r', encoding='utf-8') as f:
    content = f.read()

# The problem is that some Chinese translations contain regular double quotes
# which break the JSON parsing. We need to find and fix these.
# The JSON format uses "key": "value" pattern.
# If a value contains unescaped double quotes, it breaks.

# Strategy: Parse line by line and fix lines where value strings contain
# unescaped quotes.

lines = content.split('\n')
fixed_lines = []
for line in lines:
    stripped = line.strip()
    # Check if this is a string value line (starts with " and contains ": ")
    if stripped.startswith('"') and '": "' in stripped:
        # Extract key and value
        match = re.match(r'^\s*"([^"]+)"\s*:\s*"(.*)"(,?)$', stripped)
        if match:
            key = match.group(1)
            value = match.group(2)
            comma = match.group(3)
            # Check if value contains unescaped quotes
            if '"' in value:
                # These are unescaped quotes in the value - escape them
                value = value.replace('"', '\\"')
                fixed_line = f'  "{key}": "{value}"{comma}'
                fixed_lines.append(fixed_line)
                continue
    fixed_lines.append(line)

# Write back
with open(ZH_PATH, 'w', encoding='utf-8') as f:
    f.write('\n'.join(fixed_lines))

print("Fixed embedded quotes in app_zh.arb")

# Verify it's valid JSON
with open(ZH_PATH, 'r', encoding='utf-8') as f:
    try:
        data = json.load(f)
        print(f"JSON is valid. {len(data)} keys found.")
    except json.JSONDecodeError as e:
        print(f"JSON still has errors: {e}")
