#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import json, os
ZH = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'lib', 'l10n', 'app_zh.arb')
EN = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'lib', 'l10n', 'app_en.arb')
zh = json.load(open(ZH, 'r', encoding='utf-8'))
en = json.load(open(EN, 'r', encoding='utf-8'))
T = {}
exec(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'zh_translations.py'), 'r', encoding='utf-8').read())
for k, v in T.items():
    if k in en and (k not in zh or zh.get(k) == en.get(k)):
        zh[k] = v
for k in en:
    if k.startswith('@') and k[1:] in zh and k not in zh:
        zh[k] = en[k]
with open(ZH, 'w', encoding='utf-8') as f:
    json.dump(zh, f, ensure_ascii=False, indent=2)
en_keys = [k for k in en if not k.startswith('@')]
zh_keys = [k for k in zh if not k.startswith('@')]
untranslated = [k for k in en_keys if zh.get(k) == en.get(k) and k != 'appTitle']
print(f'English: {len(en_keys)}, Chinese: {len(zh_keys)}, Untranslated: {len(untranslated)}')
