from PIL import Image, ImageDraw

def create_icon():
    # Create a 1024x1024 black image
    size = 1024
    img = Image.new('RGB', (size, size), color=(22, 22, 24))  # Soft dark gray to match app theme
    
    # Draw a white circle (the "point")
    draw = ImageDraw.Draw(img)
    center = size // 2
    radius = size // 4
    
    # Draw the point (white circle)
    bbox = [center - radius, center - radius, center + radius, center + radius]
    draw.ellipse(bbox, fill=(234, 234, 234))  # Off-white
    
    # Add a smaller accent dot inside for some style
    accent_radius = radius // 5
    accent_bbox = [center - accent_radius, center - accent_radius, center + accent_radius, center + accent_radius]
    draw.ellipse(accent_bbox, fill=(22, 22, 24)) # Dark dot inside
    
    img.save('assets/icon.png')

if __name__ == '__main__':
    create_icon()
