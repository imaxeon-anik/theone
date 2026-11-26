"""Compare a rendered keyboard with the reference screenshot.

python3 scripts/compare.py [rendered.png]  ->  preview/out/compare.png and a score.
The reference is your own 618 px wide screenshot of the dark iPhone keyboard, saved as
preview/local/reference.png (not in the repo: it is Apple's artwork).
The reference's top bar (suggestion text) and the mic are ignored: theOne leaves them out.
"""
import sys
from pathlib import Path
from PIL import Image, ImageChops, ImageDraw

root = Path(__file__).resolve().parent.parent
ref_path = root / "preview/local/reference.png"
if not ref_path.exists():
    sys.exit("Put your reference screenshot at %s first." % ref_path)
ref = Image.open(ref_path).convert("RGB")
out = Image.open(sys.argv[1] if len(sys.argv) > 1 else root / "preview/out/letters-shift.png").convert("RGB")
out = out.resize(ref.size) if out.size != ref.size else out

# Masks: suggestion-bar text and the mic icon exist only in the reference.
masked_ref = ref.copy()
d = ImageDraw.Draw(masked_ref)
bg = (31, 31, 31)
d.rectangle((0, 0, ref.width, 66), fill=bg)
d.rectangle((520, 395, 600, 480), fill=bg)
masked_out = out.copy()
d2 = ImageDraw.Draw(masked_out)
d2.rectangle((0, 0, ref.width, 66), fill=bg)
# Rounded black screen corners in the screenshot are the phone bezel, not the keyboard.
for img in (masked_ref, masked_out):
    dd = ImageDraw.Draw(img)
    for box in ((0, 0, 40, 40), (ref.width - 40, 0, ref.width, 40),
                (0, ref.height - 40, 40, ref.height), (ref.width - 40, ref.height - 40, ref.width, ref.height)):
        dd.rectangle(box, fill=bg)

diff = ImageChops.difference(masked_ref, masked_out).convert("L")
px = list(diff.getdata()) if not hasattr(diff, "get_flattened_data") else list(diff.get_flattened_data())
bad = sum(1 for v in px if v > 40)
print(f"pixels differing by >40/255: {bad} of {len(px)} ({100.0 * bad / len(px):.2f}%)")
print(f"mean abs difference: {sum(px) / len(px):.2f}")

boost = diff.point(lambda v: min(255, v * 4))
sheet = Image.new("RGB", (ref.width * 3 + 40, ref.height + 40), (255, 255, 255))
sheet.paste(ref, (0, 40))
sheet.paste(out, (ref.width + 20, 40))
sheet.paste(Image.merge("RGB", (boost, boost, boost)), (2 * ref.width + 40, 40))
dd = ImageDraw.Draw(sheet)
for i, t in enumerate(("reference (iPhone)", "theOne", "difference x4")):
    dd.text((i * (ref.width + 20) + 8, 12), t, fill=(0, 0, 0))
sheet.save(root / "preview/out/compare.png")
