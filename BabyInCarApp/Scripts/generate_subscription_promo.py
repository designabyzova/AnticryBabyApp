#!/usr/bin/env python3
"""
Generate a 1024x1024 promotional image for App Store IAP/subscription metadata.
Requirements: JPG or PNG, 1024x1024, 72 dpi, RGB, flattened, no rounded corners.
"""

from PIL import Image, ImageDraw, ImageFont
import os
import math

# --- Configuration ---
SIZE = 1024
DPI = 72
OUTPUT_DIR = os.path.dirname(os.path.abspath(__file__))
OUTPUT_PATH = os.path.join(OUTPUT_DIR, "..", "fastlane", "metadata", "subscription_promo_1024x1024.png")

# App brand colors (from Colors.swift)
BG_COLOR = (253, 249, 243)          # appBackground: #FDF9F3 Warm Cream
PRIMARY = (155, 141, 199)            # appPrimary: #9B8DC7 Soft Lavender
PRIMARY_DARK = (123, 107, 167)       # appPrimaryDark: #7B6BA7
PRIMARY_LIGHT = (196, 184, 224)      # appPrimaryLight: #C4B8E0
SECONDARY = (232, 196, 155)          # appSecondary: #E8C49B Warm Peach
TEXT_COLOR = (45, 49, 66)            # appText: #2D3142 Ink Blue
TEXT_SECONDARY = (107, 114, 128)     # appTextSecondary: #6B7280
SUCCESS = (110, 191, 139)            # appSuccess: #6EBF8B Soft Mint
STAR_COLOR = (245, 200, 66)         # Yellow star
WHITE = (255, 255, 255)

def get_font(size, bold=False):
    """Get system font, fallback to default."""
    font_paths = [
        "/System/Library/Fonts/SFCompact.ttf",
        "/System/Library/Fonts/SFNS.ttf",
        "/System/Library/Fonts/SFNSDisplay.ttf",
        "/Library/Fonts/SF-Pro-Display-Bold.otf" if bold else "/Library/Fonts/SF-Pro-Display-Regular.otf",
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf" if bold else "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
    ]
    for path in font_paths:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size)
            except Exception:
                continue
    return ImageFont.load_default()

def draw_star(draw, cx, cy, outer_r, inner_r, color, points=5):
    """Draw a filled star shape."""
    coords = []
    for i in range(points * 2):
        angle = math.pi / 2 + i * math.pi / points
        r = outer_r if i % 2 == 0 else inner_r
        x = cx + r * math.cos(angle)
        y = cy - r * math.sin(angle)
        coords.append((x, y))
    draw.polygon(coords, fill=color)

def draw_rounded_rect(draw, xy, radius, fill=None, outline=None, width=1):
    """Draw a rectangle with rounded corners."""
    x0, y0, x1, y1 = xy
    # Clamp radius to avoid negative dimensions
    max_r = min((x1 - x0) // 2, (y1 - y0) // 2)
    radius = min(radius, max_r)
    if radius < 1:
        if fill:
            draw.rectangle([x0, y0, x1, y1], fill=fill)
        if outline:
            draw.rectangle([x0, y0, x1, y1], outline=outline, width=width)
        return
    # Fill
    if fill:
        draw.rectangle([x0 + radius, y0, x1 - radius, y1], fill=fill)
        draw.rectangle([x0, y0 + radius, x1, y1 - radius], fill=fill)
        draw.pieslice([x0, y0, x0 + 2*radius, y0 + 2*radius], 180, 270, fill=fill)
        draw.pieslice([x1 - 2*radius, y0, x1, y0 + 2*radius], 270, 360, fill=fill)
        draw.pieslice([x0, y1 - 2*radius, x0 + 2*radius, y1], 90, 180, fill=fill)
        draw.pieslice([x1 - 2*radius, y1 - 2*radius, x1, y1], 0, 90, fill=fill)
    # Outline
    if outline:
        draw.arc([x0, y0, x0 + 2*radius, y0 + 2*radius], 180, 270, fill=outline, width=width)
        draw.arc([x1 - 2*radius, y0, x1, y0 + 2*radius], 270, 360, fill=outline, width=width)
        draw.arc([x0, y1 - 2*radius, x0 + 2*radius, y1], 90, 180, fill=outline, width=width)
        draw.arc([x1 - 2*radius, y1 - 2*radius, x1, y1], 0, 90, fill=outline, width=width)
        draw.line([x0 + radius, y0, x1 - radius, y0], fill=outline, width=width)
        draw.line([x0 + radius, y1, x1 - radius, y1], fill=outline, width=width)
        draw.line([x0, y0 + radius, x0, y1 - radius], fill=outline, width=width)
        draw.line([x1, y0 + radius, x1, y1 - radius], fill=outline, width=width)

def draw_circle(draw, cx, cy, r, fill=None, outline=None, width=1):
    """Draw a circle."""
    draw.ellipse([cx-r, cy-r, cx+r, cy+r], fill=fill, outline=outline, width=width)

def draw_feature_icon(draw, cx, cy, icon_type, color):
    """Draw a simple SF Symbol-like icon."""
    r = 14
    if icon_type == "infinity":
        # Draw infinity symbol as two overlapping circles
        draw.arc([cx-20, cy-10, cx-2, cy+10], 0, 360, fill=color, width=3)
        draw.arc([cx+2, cy-10, cx+20, cy+10], 0, 360, fill=color, width=3)
    elif icon_type == "download":
        # Arrow down in circle
        draw_circle(draw, cx, cy, r, fill=color)
        # Arrow
        draw.line([cx, cy-7, cx, cy+5], fill=WHITE, width=3)
        draw.line([cx-5, cy+1, cx, cy+7], fill=WHITE, width=3)
        draw.line([cx+5, cy+1, cx, cy+7], fill=WHITE, width=3)
    elif icon_type == "globe":
        # Globe
        draw_circle(draw, cx, cy, r, fill=color)
        draw.line([cx-r, cy, cx+r, cy], fill=WHITE, width=2)
        draw.arc([cx-7, cy-r, cx+7, cy+r], 0, 360, fill=WHITE, width=2)
    elif icon_type == "warning":
        # Triangle with !
        draw.polygon([(cx, cy-r), (cx-r, cy+r), (cx+r, cy+r)], fill=color)
        draw.line([cx, cy-4, cx, cy+4], fill=WHITE, width=3)
        draw.ellipse([cx-2, cy+6, cx+2, cy+10], fill=WHITE)
    elif icon_type == "car":
        # Car shape
        draw_circle(draw, cx, cy, r, fill=color)
        draw.rectangle([cx-9, cy-3, cx+9, cy+5], fill=WHITE)
        draw.rectangle([cx-6, cy-7, cx+6, cy-2], fill=WHITE)
    elif icon_type == "waveform":
        # Waveform bars
        draw_circle(draw, cx, cy, r, fill=color)
        for i, h in enumerate([5, 9, 12, 9, 5]):
            x = cx - 8 + i * 4
            draw.line([x, cy - h//2, x, cy + h//2], fill=WHITE, width=2)


def main():
    # Create base image
    img = Image.new("RGB", (SIZE, SIZE), BG_COLOR)
    draw = ImageDraw.Draw(img)

    # --- Subtle gradient background at top ---
    for y in range(200):
        alpha = 1.0 - y / 200.0
        r = int(BG_COLOR[0] * (1 - alpha * 0.05) + PRIMARY_LIGHT[0] * alpha * 0.05)
        g = int(BG_COLOR[1] * (1 - alpha * 0.05) + PRIMARY_LIGHT[1] * alpha * 0.05)
        b = int(BG_COLOR[2] * (1 - alpha * 0.05) + PRIMARY_LIGHT[2] * alpha * 0.05)
        draw.line([(0, y), (SIZE, y)], fill=(r, g, b))

    # --- Star icon ---
    star_y = 100
    draw_star(draw, SIZE // 2, star_y, 45, 20, STAR_COLOR)

    # --- Title ---
    title_font = get_font(52, bold=True)
    subtitle_font = get_font(24)

    title = "Upgrade to Premium"
    bbox = draw.textbbox((0, 0), title, font=title_font)
    tw = bbox[2] - bbox[0]
    draw.text(((SIZE - tw) // 2, 160), title, fill=TEXT_COLOR, font=title_font)

    subtitle = "Unlock all features and content"
    bbox = draw.textbbox((0, 0), subtitle, font=subtitle_font)
    sw = bbox[2] - bbox[0]
    draw.text(((SIZE - sw) // 2, 225), subtitle, fill=TEXT_SECONDARY, font=subtitle_font)

    # --- Features list ---
    feature_font = get_font(22)
    features = [
        ("infinity", "100% content library access"),
        ("download", "Unlimited offline downloads"),
        ("globe", "All 10+ language fairy tales"),
        ("warning", "Unlimited emergency cry-stop"),
        ("car", "CarPlay & Android Auto"),
        ("waveform", "Advanced AI personalization"),
    ]

    feat_start_y = 280
    feat_x = 180
    icon_x = 150

    for i, (icon_type, text) in enumerate(features):
        y = feat_start_y + i * 42
        draw_feature_icon(draw, icon_x, y + 10, icon_type, PRIMARY)
        draw.text((feat_x, y), text, fill=TEXT_COLOR, font=feature_font)

    # --- Plan cards ---
    card_margin = 60
    card_width = SIZE - card_margin * 2
    card_radius = 16

    plans = [
        {"name": "Premium", "desc": "Monthly subscription", "price": "$6.99", "period": "/month",
         "equiv": None, "savings": None, "best": False, "selected": False, "height": 85},
        {"name": "Premium Yearly", "desc": "Best value", "price": "$49.99", "period": "/year",
         "equiv": "$4.17/mo", "savings": "Save 40%", "best": True, "selected": False, "height": 100},
        {"name": "Lifetime", "desc": "One-time purchase", "price": "$149.99", "period": " one-time",
         "equiv": None, "savings": None, "best": False, "selected": True, "height": 85},
    ]

    cards_start_y = 545
    name_font = get_font(24, bold=True)
    desc_font = get_font(16)
    price_font = get_font(26, bold=True)
    period_font = get_font(16)
    badge_font = get_font(13, bold=True)
    equiv_font = get_font(15)

    card_y_offset = cards_start_y
    for i, plan in enumerate(plans):
        card_height = plan["height"]
        y = card_y_offset
        card_y_offset += card_height + 14
        x0, y0, x1, y1 = card_margin, y, card_margin + card_width, y + card_height

        # Card background
        if plan["selected"]:
            draw_rounded_rect(draw, (x0, y0, x1, y1), card_radius, fill=WHITE, outline=PRIMARY, width=3)
        else:
            draw_rounded_rect(draw, (x0, y0, x1, y1), card_radius, fill=WHITE, outline=(230, 230, 230), width=1)

        # Plan name
        name_x = x0 + 24
        name_y = y0 + 18
        draw.text((name_x, name_y), plan["name"], fill=TEXT_COLOR, font=name_font)

        # Best value badge
        if plan["best"]:
            badge_text = "BEST VALUE"
            name_bbox = draw.textbbox((name_x, name_y), plan["name"], font=name_font)
            badge_x = name_bbox[2] + 12
            badge_y = name_y + 2
            b_bbox = draw.textbbox((0, 0), badge_text, font=badge_font)
            bw = b_bbox[2] - b_bbox[0]
            bh = b_bbox[3] - b_bbox[1]
            pill_x0 = badge_x
            pill_y0 = badge_y
            pill_x1 = badge_x + bw + 16
            pill_y1 = badge_y + bh + 8
            draw_rounded_rect(draw, (pill_x0, pill_y0, pill_x1, pill_y1), 10, fill=SUCCESS)
            draw.text((pill_x0 + 8, pill_y0 + 3), badge_text, fill=WHITE, font=badge_font)

        # Description
        draw.text((name_x, name_y + 30), plan["desc"], fill=TEXT_SECONDARY, font=desc_font)

        # Price (right side)
        price_text = plan["price"]
        period_text = plan["period"]
        p_bbox = draw.textbbox((0, 0), price_text, font=price_font)
        pw = p_bbox[2] - p_bbox[0]
        per_bbox = draw.textbbox((0, 0), period_text, font=period_font)
        perw = per_bbox[2] - per_bbox[0]

        price_right = x1 - 60
        price_x = price_right - pw - perw
        price_y = y0 + 20

        draw.text((price_x, price_y), price_text, fill=TEXT_COLOR, font=price_font)
        draw.text((price_x + pw + 2, price_y + 6), period_text, fill=TEXT_SECONDARY, font=period_font)

        # Equivalent price / savings (stacked right-aligned)
        sub_y = price_y + 32
        if plan["equiv"]:
            e_bbox = draw.textbbox((0, 0), plan["equiv"], font=equiv_font)
            ew = e_bbox[2] - e_bbox[0]
            draw.text((price_right - ew, sub_y), plan["equiv"], fill=TEXT_SECONDARY, font=equiv_font)
            sub_y += 18
        if plan["savings"]:
            s_bbox = draw.textbbox((0, 0), plan["savings"], font=equiv_font)
            sw2 = s_bbox[2] - s_bbox[0]
            draw.text((price_right - sw2, sub_y), plan["savings"], fill=SUCCESS, font=equiv_font)

        # Radio button
        radio_x = x1 - 36
        radio_y = y0 + card_height // 2
        if plan["selected"]:
            draw_circle(draw, radio_x, radio_y, 14, outline=PRIMARY, width=3)
            draw_circle(draw, radio_x, radio_y, 9, fill=PRIMARY)
        else:
            draw_circle(draw, radio_x, radio_y, 14, outline=(200, 200, 200), width=2)

    # --- Subscribe button ---
    btn_y = card_y_offset + 10
    btn_height = 60
    btn_margin = 60
    draw_rounded_rect(
        draw,
        (btn_margin, btn_y, SIZE - btn_margin, btn_y + btn_height),
        14,
        fill=PRIMARY
    )
    btn_font = get_font(26, bold=True)
    btn_text = "Subscribe Now"
    b_bbox = draw.textbbox((0, 0), btn_text, font=btn_font)
    btw = b_bbox[2] - b_bbox[0]
    draw.text(((SIZE - btw) // 2, btn_y + 14), btn_text, fill=WHITE, font=btn_font)

    # --- Save with correct specs ---
    os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)

    # Ensure RGB, flattened (no alpha), 72 DPI
    img = img.convert("RGB")
    img.save(OUTPUT_PATH, "PNG", dpi=(DPI, DPI))

    # Also save as JPG
    jpg_path = OUTPUT_PATH.replace(".png", ".jpg")
    img.save(jpg_path, "JPEG", dpi=(DPI, DPI), quality=95)

    print(f"PNG saved: {OUTPUT_PATH}")
    print(f"JPG saved: {jpg_path}")

    # Verify
    verify = Image.open(OUTPUT_PATH)
    print(f"Dimensions: {verify.size[0]}x{verify.size[1]}")
    print(f"Mode: {verify.mode}")
    print(f"DPI: {verify.info.get('dpi', 'not set')}")
    print(f"Format: {verify.format}")


if __name__ == "__main__":
    main()
