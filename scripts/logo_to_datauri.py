#!/usr/bin/env python3
"""Convert the Edu Oasis logo to an optimized RGB base64 data URI for embedding."""
import base64, io
from PIL import Image

SRC = "/home/z/my-project/upload/LOGO EDU OASIS NEW COLOR-01.jpg"
OUT = "/home/z/my-project/scripts/logo_datauri.txt"

im = Image.open(SRC)
print("source:", im.size, im.mode)
if im.mode != "RGB":
    im = im.convert("RGB")

# Resize to a crisp mark size (2x for retina at ~36px display)
im = im.resize((256, 256), Image.LANCZOS)

buf = io.BytesIO()
im.save(buf, format="JPEG", quality=88, optimize=True)
data = buf.getvalue()
print("jpeg bytes:", len(data))

b64 = base64.b64encode(data).decode("ascii")
uri = f"data:image/jpeg;base64,{b64}"

with open(OUT, "w") as f:
    f.write(uri)
print("data uri chars:", len(uri))
print("saved ->", OUT)
