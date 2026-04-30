from PIL import Image

img = Image.open('icon.png').convert('RGB')
pixels = img.load()
w, h = img.size

min_x, min_y = w, h
max_x, max_y = 0, 0

for y in range(h):
    for x in range(w):
        r, g, b = pixels[x, y]
        # the border is around 59, 63, 66.
        # if any channel is > 100, it's definitely the logo part
        if r > 100 or g > 100 or b > 100:
            if x < min_x: min_x = x
            if x > max_x: max_x = x
            if y < min_y: min_y = y
            if y > max_y: max_y = y

print(f"Inner logo bounds: {min_x},{min_y} to {max_x},{max_y}")
if min_x < max_x and min_y < max_y:
    img = Image.open('icon.png')
    cropped = img.crop((min_x, min_y, max_x + 1, max_y + 1))
    cropped.save('icon.png')
