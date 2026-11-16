#!/usr/bin/env python3
"""Inject the Edu Oasis logo (data URI) into the 3 brand locations in the LMS HTML."""
HTML = "/home/z/my-project/download/edu-oasis-lms.html"
URI = open("/home/z/my-project/scripts/logo_datauri.txt").read().strip()

with open(HTML, encoding="utf-8") as f:
    src = f.read()

before = src

# 1) Public header mark
src = src.replace(
    '<div class="logo" onclick="R.go(\'\')" style="cursor:pointer"><div class="mark">E</div>',
    f'<div class="logo" onclick="R.go(\'\')" style="cursor:pointer"><img class="mark" src="{URI}" alt="Logo Edu Oasis" />',
    1,
)

# 2) App sidebar mark
src = src.replace(
    '<div class="logo mb" onclick="R.go(\'dashboard\')" style="cursor:pointer"><div class="mark">E</div>',
    f'<div class="logo mb" onclick="R.go(\'dashboard\')" style="cursor:pointer"><img class="mark" src="{URI}" alt="Logo Edu Oasis" />',
    1,
)

# 3) Login page mark (had inline size override)
src = src.replace(
    '<div class="logo"><div class="mark" style="width:46px;height:46px;font-size:22px">E</div>',
    f'<div class="logo"><img class="mark" style="width:56px;height:56px" src="{URI}" alt="Logo Edu Oasis" />',
    1,
)

assert src != before, "No replacements made — selectors did not match"
assert src.count(URI) == 3, f"Expected 3 logo injections, got {src.count(URI)}"

with open(HTML, "w", encoding="utf-8") as f:
    f.write(src)

print("Injected logo into 3 brand locations.")
print("Remaining bare 'E' marks:", src.count('<div class="mark">E</div>'))
print("img.mark count:", src.count('<img class="mark"'))
