from PIL import Image

img = Image.open('assets/images/flising-ride.png').convert('RGBA')
w, h = img.size
pixels = img.load()

# Find orange pin bounding box and sample the exact dark navy background color
min_x, min_y, max_x, max_y = w, h, 0, 0
dark_samples = []

for y in range(h):
    for x in range(w):
        r, g, b, a = pixels[x, y]
        if a > 128:
            if r > 160 and g > 50 and b < 90:
                if x < min_x: min_x = x
                if y < min_y: min_y = y
                if x > max_x: max_x = x
                if y > max_y: max_y = y
            elif r < 45 and g < 45 and b < 60:
                dark_samples.append((r, g, b))

bg_rgb = dark_samples[len(dark_samples) // 2] if dark_samples else (11, 16, 23)
bg_color = (bg_rgb[0], bg_rgb[1], bg_rgb[2], 255)

# Replace any outer white/gray corner pixels outside the inner 'F' with dark navy
cx, cy = (min_x + max_x) / 2.0, (min_y + max_y) / 2.0
rx, ry = (max_x - min_x) * 0.32, (max_y - min_y) * 0.32

for y in range(h):
    for x in range(w):
        r, g, b, a = pixels[x, y]
        inside_f_zone = ((x - cx) ** 2) / (rx ** 2 + 1) + ((y - cy) ** 2) / (ry ** 2 + 1) <= 1.0
        if not inside_f_zone:
            if not (r > 140 and g > 40 and b < 100):
                pixels[x, y] = bg_color

# Crop tightly to the orange pin and scale to 450px tall inside a 1024x1024 canvas
pin_crop = img.crop((min_x, min_y, max_x + 1, max_y + 1))
canvas = Image.new('RGBA', (1024, 1024), bg_color)
target_h = 450
target_w = int(pin_crop.width * (target_h / float(pin_crop.height)))
pin_resized = pin_crop.resize((target_w, target_h), Image.LANCZOS)
canvas.paste(pin_resized, ((1024 - target_w) // 2, (1024 - target_h) // 2))
canvas.convert('RGB').save('assets/images/flising-ride.png', 'PNG')
print("Successfully padded flising-ride.png to match Flising Driver proportions")
