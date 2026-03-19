#!/usr/bin/env python3
"""
Generate IAP Review Screenshots for App Store Connect.

Apple IAP Review Screenshot Requirements:
- Format: JPG or PNG
- Dimensions: Must match a valid App Store screenshot device size
- Purpose: Show the item/service being offered (for review only, not displayed)
- One screenshot per IAP product
- Must clearly show the subscription/purchase UI as it appears in the app

We generate 3 screenshots (one per IAP), each highlighting the selected plan:
1. Monthly Premium ($6.99/month) - selected
2. Yearly Premium ($49.99/year) - selected
3. Lifetime Premium ($149.99 one-time) - selected

Target: iPhone 6.7" (1290x2796) - standard App Store dimension
"""

from PIL import Image, ImageDraw, ImageFont
import os
import math

# --- Dimensions ---
WIDTH = 1290
HEIGHT = 2796

# App brand colors (from Colors.swift)
BG_COLOR = (253, 249, 243)          # appBackground: #FDF9F3 Warm Cream
PRIMARY = (155, 141, 199)            # appPrimary: #9B8DC7 Soft Lavender
PRIMARY_DARK = (123, 107, 167)       # appPrimaryDark: #7B6BA7
PRIMARY_LIGHT = (196, 184, 224)      # appPrimaryLight: #C4B8E0
TEXT_COLOR = (45, 49, 66)            # appText: #2D3142 Ink Blue
TEXT_SECONDARY = (107, 114, 128)     # appTextSecondary: #6B7280
SUCCESS = (110, 191, 139)            # appSuccess: #6EBF8B Soft Mint
STAR_COLOR = (245, 200, 66)         # Yellow star
WHITE = (255, 255, 255)
CARD_SHADOW = (230, 225, 218)
CLOSE_BLUE = (0, 122, 255)          # iOS system blue
DIVIDER = (230, 228, 224)
HOME_INDICATOR = (180, 175, 168)

OUTPUT_DIR = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "..", "fastlane", "metadata", "review_screenshots"
)


def get_font(size, bold=False):
    """Get system font with fallback chain."""
    paths_bold = [
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
        "/Library/Fonts/Arial Bold.ttf",
    ]
    paths_regular = [
        "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/Library/Fonts/Arial.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
    ]
    for path in (paths_bold if bold else paths_regular):
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size)
            except Exception:
                continue
    return ImageFont.load_default()


def draw_star(draw, cx, cy, outer_r, inner_r, color, points=5):
    """Draw a filled star."""
    coords = []
    for i in range(points * 2):
        angle = math.pi / 2 + i * math.pi / points
        r = outer_r if i % 2 == 0 else inner_r
        coords.append((cx + r * math.cos(angle), cy - r * math.sin(angle)))
    draw.polygon(coords, fill=color)


def draw_rounded_rect(draw, xy, radius, fill=None, outline=None, width=1):
    """Draw a rectangle with rounded corners."""
    x0, y0, x1, y1 = [int(v) for v in xy]
    max_r = min((x1 - x0) // 2, (y1 - y0) // 2)
    radius = min(radius, max(max_r, 0))
    if radius < 1:
        if fill:
            draw.rectangle([x0, y0, x1, y1], fill=fill)
        if outline:
            draw.rectangle([x0, y0, x1, y1], outline=outline, width=width)
        return
    if fill:
        draw.rectangle([x0 + radius, y0, x1 - radius, y1], fill=fill)
        draw.rectangle([x0, y0 + radius, x1, y1 - radius], fill=fill)
        draw.pieslice([x0, y0, x0 + 2 * radius, y0 + 2 * radius], 180, 270, fill=fill)
        draw.pieslice([x1 - 2 * radius, y0, x1, y0 + 2 * radius], 270, 360, fill=fill)
        draw.pieslice([x0, y1 - 2 * radius, x0 + 2 * radius, y1], 90, 180, fill=fill)
        draw.pieslice([x1 - 2 * radius, y1 - 2 * radius, x1, y1], 0, 90, fill=fill)
    if outline:
        draw.arc([x0, y0, x0 + 2 * radius, y0 + 2 * radius], 180, 270, fill=outline, width=width)
        draw.arc([x1 - 2 * radius, y0, x1, y0 + 2 * radius], 270, 360, fill=outline, width=width)
        draw.arc([x0, y1 - 2 * radius, x0 + 2 * radius, y1], 90, 180, fill=outline, width=width)
        draw.arc([x1 - 2 * radius, y1 - 2 * radius, x1, y1], 0, 90, fill=outline, width=width)
        draw.line([x0 + radius, y0, x1 - radius, y0], fill=outline, width=width)
        draw.line([x0 + radius, y1, x1 - radius, y1], fill=outline, width=width)
        draw.line([x0, y0 + radius, x0, y1 - radius], fill=outline, width=width)
        draw.line([x1, y0 + radius, x1, y1 - radius], fill=outline, width=width)


def draw_circle(draw, cx, cy, r, fill=None, outline=None, width=1):
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=fill, outline=outline, width=width)


def draw_checkmark(draw, cx, cy, size, color):
    """Draw a checkmark icon."""
    draw.line([cx - size * 0.4, cy, cx - size * 0.1, cy + size * 0.3], fill=color, width=max(3, size // 5))
    draw.line([cx - size * 0.1, cy + size * 0.3, cx + size * 0.4, cy - size * 0.3], fill=color, width=max(3, size // 5))


def text_center_x(draw, text, font):
    """Get x position to center text."""
    bbox = draw.textbbox((0, 0), text, font=font)
    return (WIDTH - (bbox[2] - bbox[0])) // 2


def text_width(draw, text, font):
    bbox = draw.textbbox((0, 0), text, font=font)
    return bbox[2] - bbox[0]


def generate_screenshot(selected_index, filename):
    """
    Generate a single IAP review screenshot.
    selected_index: 0=Monthly, 1=Yearly, 2=Lifetime
    """
    img = Image.new("RGB", (WIDTH, HEIGHT), BG_COLOR)
    draw = ImageDraw.Draw(img)

    # Content is vertically centered in the safe area (below status bar, above home indicator)
    # Status bar: 0-130, Home indicator: 2730-2796, Safe area: 130-2730 = 2600px
    safe_top = 130
    safe_bottom = 2730
    safe_height = safe_bottom - safe_top

    # --- iOS Status Bar (simple) ---
    status_font = get_font(42, bold=True)
    draw.text((60, 50), "9:41", fill=TEXT_COLOR, font=status_font)
    # Battery/signal right side (simplified dots)
    for i in range(4):
        h = 16 + i * 3
        x = WIDTH - 200 + i * 18
        draw.rectangle([x, 60 - h // 2, x + 10, 60 + h // 2], fill=TEXT_COLOR)
    # Battery
    draw.rounded_rectangle([WIDTH - 110, 45, WIDTH - 50, 75], radius=5, outline=TEXT_COLOR, width=2)
    draw.rectangle([WIDTH - 105, 50, WIDTH - 55, 70], fill=SUCCESS)
    draw.rectangle([WIDTH - 48, 53, WIDTH - 45, 67], fill=TEXT_COLOR)

    # --- Navigation Bar ---
    nav_y = safe_top
    close_font = get_font(48)
    draw.text((55, nav_y + 15), "Close", fill=CLOSE_BLUE, font=close_font)

    # Thin separator
    sep_y = nav_y + 85
    draw.line([(0, sep_y), (WIDTH, sep_y)], fill=DIVIDER, width=2)

    # --- Content starts here, vertically distributed ---
    content_top = sep_y + 50
    # We'll layout content from top, ensuring it fills to bottom

    # --- Gradient wash ---
    for y in range(content_top, content_top + 250):
        alpha = 1.0 - (y - content_top) / 250.0
        r = int(BG_COLOR[0] + (PRIMARY_LIGHT[0] - BG_COLOR[0]) * alpha * 0.08)
        g = int(BG_COLOR[1] + (PRIMARY_LIGHT[1] - BG_COLOR[1]) * alpha * 0.08)
        b = int(BG_COLOR[2] + (PRIMARY_LIGHT[2] - BG_COLOR[2]) * alpha * 0.08)
        draw.line([(0, y), (WIDTH, y)], fill=(r, g, b))

    # --- Star icon ---
    star_cy = content_top + 100
    draw_star(draw, WIDTH // 2, star_cy, 72, 32, STAR_COLOR)

    # --- Title ---
    title_font = get_font(72, bold=True)
    subtitle_font = get_font(38)

    title = "Upgrade to Premium"
    title_y = star_cy + 95
    draw.text((text_center_x(draw, title, title_font), title_y), title, fill=TEXT_COLOR, font=title_font)

    subtitle = "Unlock all features and content"
    sub_y = title_y + 90
    draw.text((text_center_x(draw, subtitle, subtitle_font), sub_y), subtitle, fill=TEXT_SECONDARY, font=subtitle_font)

    # --- Features list with checkmark icons ---
    feature_font = get_font(40)
    features = [
        "100% content library access",
        "Unlimited offline downloads",
        "All 10+ language fairy tales",
        "Unlimited emergency cry-stop",
        "CarPlay support",
        "Advanced AI personalization",
    ]

    feat_start_y = sub_y + 90
    feat_left = 130
    icon_cx = 105
    feat_spacing = 70

    for i, feat_text in enumerate(features):
        y = feat_start_y + i * feat_spacing
        # Lavender circle background
        draw_circle(draw, icon_cx, y + 20, 25, fill=PRIMARY)
        # White checkmark inside
        draw_checkmark(draw, icon_cx, y + 20, 18, WHITE)
        draw.text((feat_left + 40, y), feat_text, fill=TEXT_COLOR, font=feature_font)

    # --- Plan Cards ---
    card_margin = 55
    card_width = WIDTH - card_margin * 2
    card_radius = 28

    plans = [
        {
            "name": "Premium",
            "desc": "Monthly subscription",
            "price": "$6.99",
            "period": "/month",
            "equiv": None,
            "savings": None,
            "best": False,
            "height": 170,
        },
        {
            "name": "Premium Yearly",
            "desc": "Best value — save 40%",
            "price": "$49.99",
            "period": "/year",
            "equiv": "$4.17/mo",
            "savings": "Save 40%",
            "best": True,
            "height": 200,
        },
        {
            "name": "Lifetime",
            "desc": "One-time purchase",
            "price": "$149.99",
            "period": " one-time",
            "equiv": "Never pay again",
            "savings": None,
            "best": False,
            "height": 170,
        },
    ]

    cards_start_y = feat_start_y + len(features) * feat_spacing + 50
    name_font = get_font(42, bold=True)
    desc_font = get_font(30)
    price_font = get_font(46, bold=True)
    period_font = get_font(28)
    badge_font = get_font(24, bold=True)
    equiv_font = get_font(28)

    card_y = cards_start_y
    card_gap = 22

    for i, plan in enumerate(plans):
        is_selected = (i == selected_index)
        ch = plan["height"]
        x0 = card_margin
        y0 = card_y
        x1 = card_margin + card_width
        y1 = card_y + ch

        # Card shadow (subtle)
        if is_selected:
            draw_rounded_rect(draw, (x0 + 4, y0 + 6, x1 + 4, y1 + 6), card_radius, fill=(220, 215, 230))

        # Card background
        if is_selected:
            draw_rounded_rect(draw, (x0, y0, x1, y1), card_radius, fill=WHITE, outline=PRIMARY, width=4)
        else:
            draw_rounded_rect(draw, (x0, y0, x1, y1), card_radius, fill=WHITE, outline=(220, 218, 214), width=2)

        # Plan name
        nx = x0 + 35
        ny = y0 + 30
        draw.text((nx, ny), plan["name"], fill=TEXT_COLOR, font=name_font)

        # Best value badge
        if plan["best"]:
            badge_text = "BEST VALUE"
            name_bbox = draw.textbbox((nx, ny), plan["name"], font=name_font)
            bx = name_bbox[2] + 18
            by = ny + 5
            bb = draw.textbbox((0, 0), badge_text, font=badge_font)
            bw = bb[2] - bb[0]
            bh = bb[3] - bb[1]
            draw_rounded_rect(draw, (bx, by, bx + bw + 22, by + bh + 14), 14, fill=SUCCESS)
            draw.text((bx + 11, by + 6), badge_text, fill=WHITE, font=badge_font)

        # Description
        draw.text((nx, ny + 55), plan["desc"], fill=TEXT_SECONDARY, font=desc_font)

        # Price (right side) — billed amount is MOST prominent per Apple 3.1.2
        price_right = x1 - 95
        pw = text_width(draw, plan["price"], price_font)
        perw = text_width(draw, plan["period"], period_font)
        px = price_right - pw - perw
        py = y0 + 30

        draw.text((px, py), plan["price"], fill=TEXT_COLOR, font=price_font)
        draw.text((px + pw + 3, py + 14), plan["period"], fill=TEXT_SECONDARY, font=period_font)

        # Equivalent / savings below price
        sub_line_y = py + 58
        if plan["equiv"]:
            ew = text_width(draw, plan["equiv"], equiv_font)
            color = SUCCESS if plan["equiv"] == "Never pay again" else TEXT_SECONDARY
            draw.text((price_right - ew, sub_line_y), plan["equiv"], fill=color, font=equiv_font)
            sub_line_y += 34
        if plan["savings"]:
            sw2 = text_width(draw, plan["savings"], equiv_font)
            draw.text((price_right - sw2, sub_line_y), plan["savings"], fill=SUCCESS, font=equiv_font)

        # Radio button (right edge)
        radio_x = x1 - 50
        radio_y = y0 + ch // 2
        if is_selected:
            draw_circle(draw, radio_x, radio_y, 22, outline=PRIMARY, width=4)
            draw_circle(draw, radio_x, radio_y, 14, fill=PRIMARY)
        else:
            draw_circle(draw, radio_x, radio_y, 22, outline=(200, 200, 200), width=3)

        card_y += ch + card_gap

    # --- Subscribe / Purchase button ---
    btn_margin = 55
    btn_y = card_y + 35
    btn_height = 100
    btn_radius = 20

    # Button text depends on selected plan
    if selected_index == 2:
        btn_text = "Purchase Now"
    else:
        btn_text = "Subscribe Now"

    draw_rounded_rect(
        draw,
        (btn_margin, btn_y, WIDTH - btn_margin, btn_y + btn_height),
        btn_radius,
        fill=PRIMARY,
    )
    btn_font = get_font(42, bold=True)
    bx = text_center_x(draw, btn_text, btn_font)
    draw.text((bx, btn_y + 26), btn_text, fill=WHITE, font=btn_font)

    # --- Compare Plans link ---
    link_font = get_font(32)
    link_y = btn_y + btn_height + 45
    link_text = "Compare Free vs Premium"
    draw.text((text_center_x(draw, link_text, link_font), link_y), link_text, fill=PRIMARY, font=link_font)

    # --- Restore Purchases link ---
    restore_y = link_y + 55
    restore_text = "Restore Purchases"
    draw.text((text_center_x(draw, restore_text, link_font), restore_y), restore_text, fill=PRIMARY, font=link_font)

    # --- Legal text ---
    legal_font = get_font(24)
    legal_y = restore_y + 70
    legal_lines = [
        "Payment will be charged to your Apple ID account.",
        "Subscription automatically renews unless canceled",
        "at least 24 hours before the end of the current period.",
    ]
    # For lifetime, show different legal text
    if selected_index == 2:
        legal_lines = [
            "Payment will be charged to your Apple ID account.",
            "This is a one-time purchase. No subscription.",
            "Includes all current and future premium features.",
        ]

    for j, line in enumerate(legal_lines):
        lx = text_center_x(draw, line, legal_font)
        draw.text((lx, legal_y + j * 35), line, fill=TEXT_SECONDARY, font=legal_font)

    # --- Privacy & Terms links ---
    links_y = legal_y + len(legal_lines) * 35 + 20
    links_font = get_font(24)
    links_text = "Privacy Policy  and  Terms of Use (EULA)"
    draw.text((text_center_x(draw, links_text, links_font), links_y), links_text, fill=CLOSE_BLUE, font=links_font)

    # --- Home Indicator bar (iOS standard) ---
    indicator_w = 350
    indicator_h = 12
    indicator_y = HEIGHT - 40
    indicator_x = (WIDTH - indicator_w) // 2
    draw_rounded_rect(
        draw,
        (indicator_x, indicator_y, indicator_x + indicator_w, indicator_y + indicator_h),
        indicator_h // 2,
        fill=HOME_INDICATOR,
    )

    # --- Save ---
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    output_path = os.path.join(OUTPUT_DIR, filename)
    img = img.convert("RGB")
    img.save(output_path, "PNG", dpi=(72, 72))
    print(f"  Saved: {output_path}")
    print(f"  Size: {img.size[0]}x{img.size[1]}, Mode: {img.mode}, DPI: 72")
    return output_path


def generate_promo_image():
    """Generate the 1024x1024 promotional image for IAP display."""
    SIZE = 1024
    img = Image.new("RGB", (SIZE, SIZE), BG_COLOR)
    draw = ImageDraw.Draw(img)

    # Subtle gradient top
    for y in range(250):
        alpha = 1.0 - y / 250.0
        r = int(BG_COLOR[0] + (PRIMARY_LIGHT[0] - BG_COLOR[0]) * alpha * 0.1)
        g = int(BG_COLOR[1] + (PRIMARY_LIGHT[1] - BG_COLOR[1]) * alpha * 0.1)
        b = int(BG_COLOR[2] + (PRIMARY_LIGHT[2] - BG_COLOR[2]) * alpha * 0.1)
        draw.line([(0, y), (SIZE, y)], fill=(r, g, b))

    # Star
    draw_star(draw, SIZE // 2, 110, 55, 24, STAR_COLOR)

    # Title
    title_font = get_font(52, bold=True)
    sub_font = get_font(26)
    title = "Lulla Premium"
    bbox = draw.textbbox((0, 0), title, font=title_font)
    tw = bbox[2] - bbox[0]
    draw.text(((SIZE - tw) // 2, 180), title, fill=TEXT_COLOR, font=title_font)

    subtitle = "Calm Baby Anywhere"
    bbox = draw.textbbox((0, 0), subtitle, font=sub_font)
    sw = bbox[2] - bbox[0]
    draw.text(((SIZE - sw) // 2, 242), subtitle, fill=TEXT_SECONDARY, font=sub_font)

    # Features
    feat_font = get_font(22)
    features = [
        "100% content library access",
        "Unlimited offline downloads",
        "All 10+ language fairy tales",
        "Unlimited emergency cry-stop",
        "CarPlay support",
        "Advanced AI personalization",
    ]
    feat_start = 300
    for i, feat in enumerate(features):
        y = feat_start + i * 40
        draw_circle(draw, 130, y + 12, 14, fill=PRIMARY)
        draw_checkmark(draw, 130, y + 12, 10, WHITE)
        draw.text((160, y), feat, fill=TEXT_COLOR, font=feat_font)

    # Three plan cards (compact)
    card_margin = 50
    card_w = SIZE - card_margin * 2
    card_r = 14

    plans = [
        {"name": "Monthly", "price": "$6.99/mo", "selected": False},
        {"name": "Yearly", "price": "$49.99/yr", "badge": "BEST VALUE", "sub": "$4.17/mo", "selected": True},
        {"name": "Lifetime", "price": "$149.99", "selected": False},
    ]
    name_f = get_font(24, bold=True)
    price_f = get_font(24, bold=True)
    badge_f = get_font(13, bold=True)
    sub_f = get_font(16)

    cy = 560
    for plan in plans:
        ch = 80
        x0, y0, x1, y1 = card_margin, cy, card_margin + card_w, cy + ch
        sel = plan["selected"]
        if sel:
            draw_rounded_rect(draw, (x0, y0, x1, y1), card_r, fill=WHITE, outline=PRIMARY, width=3)
        else:
            draw_rounded_rect(draw, (x0, y0, x1, y1), card_r, fill=WHITE, outline=(220, 218, 214), width=1)

        draw.text((x0 + 20, y0 + 16), plan["name"], fill=TEXT_COLOR, font=name_f)

        if "badge" in plan:
            nb = draw.textbbox((x0 + 20, y0 + 16), plan["name"], font=name_f)
            bx = nb[2] + 10
            bb = draw.textbbox((0, 0), plan["badge"], font=badge_f)
            bw = bb[2] - bb[0]
            bh = bb[3] - bb[1]
            draw_rounded_rect(draw, (bx, y0 + 18, bx + bw + 14, y0 + 18 + bh + 8), 8, fill=SUCCESS)
            draw.text((bx + 7, y0 + 21), plan["badge"], fill=WHITE, font=badge_f)

        if "sub" in plan:
            draw.text((x0 + 20, y0 + 48), plan["sub"], fill=TEXT_SECONDARY, font=sub_f)

        pw2 = text_width(draw, plan["price"], price_f)
        draw.text((x1 - 60 - pw2, y0 + 26), plan["price"], fill=TEXT_COLOR, font=price_f)

        radio_x = x1 - 34
        radio_y = y0 + ch // 2
        if sel:
            draw_circle(draw, radio_x, radio_y, 12, outline=PRIMARY, width=3)
            draw_circle(draw, radio_x, radio_y, 7, fill=PRIMARY)
        else:
            draw_circle(draw, radio_x, radio_y, 12, outline=(200, 200, 200), width=2)

        cy += ch + 12

    # Subscribe button
    btn_y2 = cy + 15
    btn_h = 56
    draw_rounded_rect(draw, (card_margin, btn_y2, SIZE - card_margin, btn_y2 + btn_h), 12, fill=PRIMARY)
    bf = get_font(26, bold=True)
    bt = "Subscribe Now"
    bb2 = draw.textbbox((0, 0), bt, font=bf)
    btw = bb2[2] - bb2[0]
    draw.text(((SIZE - btw) // 2, btn_y2 + 12), bt, fill=WHITE, font=bf)

    # Legal
    legal_f = get_font(14)
    legal = "Auto-renews. Cancel anytime."
    lb = draw.textbbox((0, 0), legal, font=legal_f)
    lw = lb[2] - lb[0]
    draw.text(((SIZE - lw) // 2, btn_y2 + btn_h + 20), legal, fill=TEXT_SECONDARY, font=legal_f)

    # Save PNG and JPG
    promo_dir = os.path.join(os.path.dirname(OUTPUT_DIR))
    os.makedirs(promo_dir, exist_ok=True)

    png_path = os.path.join(promo_dir, "subscription_promo_1024x1024.png")
    jpg_path = os.path.join(promo_dir, "subscription_promo_1024x1024.jpg")

    img = img.convert("RGB")
    img.save(png_path, "PNG", dpi=(72, 72))
    img.save(jpg_path, "JPEG", dpi=(72, 72), quality=95)

    # Also save in review_screenshots folder
    promo_review_path = os.path.join(OUTPUT_DIR, "iap_promotional_1024x1024.png")
    img.save(promo_review_path, "PNG", dpi=(72, 72))

    print(f"  PNG: {png_path}")
    print(f"  JPG: {jpg_path}")
    print(f"  Review copy: {promo_review_path}")
    print(f"  Size: {img.size[0]}x{img.size[1]}, Mode: {img.mode}")

    return png_path


def main():
    print("=" * 60)
    print("IAP Review Screenshots Generator")
    print("=" * 60)
    print(f"Target: {WIDTH}x{HEIGHT} (iPhone 6.7\") PNG, 72 DPI, RGB\n")

    screenshots = [
        (0, "iap_review_monthly_premium.png"),
        (1, "iap_review_yearly_premium.png"),
        (2, "iap_review_lifetime_premium.png"),
    ]

    plan_names = ["Monthly Premium ($6.99/month)", "Yearly Premium ($49.99/year)", "Lifetime Premium ($149.99)"]

    for selected_idx, filename in screenshots:
        print(f"[{selected_idx + 1}/3] {plan_names[selected_idx]}:")
        generate_screenshot(selected_idx, filename)
        print()

    print("[4/4] Promotional Image (1024x1024):")
    generate_promo_image()
    print()

    print("=" * 60)
    print("DONE - Upload Instructions")
    print("=" * 60)
    print(f"\nOutput: {OUTPUT_DIR}\n")
    print("IAP Review Screenshots (one per IAP in App Store Connect):")
    print(f"  1. iap_review_monthly_premium.png  -> com.babyincar.premium.monthly")
    print(f"  2. iap_review_yearly_premium.png   -> com.babyincar.premium.yearly")
    print(f"  3. iap_review_lifetime_premium.png -> com.babyincar.premium.lifetime.v2")
    print("\nPromotional (subscription group):")
    print(f"  4. subscription_promo_1024x1024.png/jpg (1024x1024)")
    print("\nUpload path in App Store Connect:")
    print("  App Store Connect -> Your App -> Subscriptions")
    print("  -> Select subscription group -> Select plan")
    print("  -> App Store Promotion (optional) / Review Information -> Screenshot")


if __name__ == "__main__":
    main()
