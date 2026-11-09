from pathlib import Path
from PIL import Image, ImageDraw

source = Image.open("assets/images/father.jpg").convert("RGB")
sizes = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
for density, size in sizes.items():
    # Preserve the entire portrait within a rounded gold frame.
    canvas = Image.new("RGB", (size, size), "#073E35")
    draw = ImageDraw.Draw(canvas)
    pad = max(3, round(size * 0.08))
    draw.rounded_rectangle((pad // 2, pad // 2, size - pad // 2 - 1, size - pad // 2 - 1),
                           radius=size // 5, fill="#D6B56C")
    inner = size - 2 * pad
    photo = source.copy()
    photo.thumbnail((inner, inner), Image.Resampling.LANCZOS)
    x = (size - photo.width) // 2
    y = (size - photo.height) // 2
    canvas.paste(photo, (x, y))
    target = Path(f"android/app/src/main/res/mipmap-{density}/ic_launcher.png")
    target.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(target)
print("Generated Android launcher icons from father's photo.")
