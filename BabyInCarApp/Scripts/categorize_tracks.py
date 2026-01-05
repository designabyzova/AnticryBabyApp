#!/usr/bin/env python3
"""
Audio Library Categorization Script
Implements FS-018: Clean separation between fairy tales and music/sounds
"""

import json
import os
from typing import Dict, Any

# English Fairy Tale Title Mappings (Grimm Brothers)
GRIMM_TITLES = {
    "grimm_briar_rose": "Sleeping Beauty",
    "grimm_cat_mouse": "Cat and Mouse in Partnership",
    "grimm_chanticleer": "Chanticleer and Partlet",
    "grimm_cinderella": "Cinderella",
    "grimm_clever_elsie": "Clever Elsie",
    "grimm_clever_gretel": "Clever Gretel",
    "grimm_dog_sparrow": "The Dog and the Sparrow",
    "grimm_fisherman_wife": "The Fisherman and His Wife",
    "grimm_frederick_catherine": "Frederick and Catherine",
    "grimm_frog_prince": "The Frog Prince",
    "grimm_fundevogel": "Foundling-Bird",
    "grimm_golden_bird": "The Golden Bird",
    "grimm_goose_girl": "The Goose Girl",
    "grimm_hans_luck": "Hans in Luck",
    "grimm_hansel_gretel": "Hansel and Gretel",
    "grimm_jorinda_jorindel": "Jorinda and Jorindel",
    "grimm_little_peasant": "The Little Peasant",
    "grimm_miser_bush": "The Miser in the Bush",
    "grimm_mother_holle": "Mother Holle",
    "grimm_mouse_bird_sausage": "The Mouse, the Bird, and the Sausage",
    "grimm_old_man_grandson": "The Old Man and His Grandson",
    "grimm_old_sultan": "Old Sultan",
    "grimm_rapunzel": "Rapunzel",
    "grimm_red_riding_hood": "Little Red Riding Hood",
    "grimm_robber_bridegroom": "The Robber Bridegroom",
    "grimm_rumpelstiltskin": "Rumpelstiltskin",
    "grimm_snow_white": "Snow White",
    "grimm_straw_coal_bean": "The Straw, the Coal, and the Bean",
    "grimm_sweetheart_roland": "Sweetheart Roland",
    "grimm_the_pink": "The Pink",
    "grimm_tom_thumb": "Tom Thumb",
    "grimm_travelling_musicians": "The Town Musicians of Bremen",
    "grimm_twelve_princesses": "The Twelve Dancing Princesses",
    "grimm_valiant_tailor": "The Brave Little Tailor",
    "grimm_willow_wren": "The Willow-Wren",
}

# Household Tales Title Mappings
HT_TITLES = {
    "ht_cat_mouse": "Cat and Mouse in Partnership",
    "ht_faithful_john": "Faithful John",
    "ht_frog_king": "The Frog King",
    "ht_good_bargain": "The Good Bargain",
    "ht_our_lady_child": "Our Lady's Child",
    "ht_pack_ragamuffins": "The Pack of Ragamuffins",
    "ht_strange_musician": "The Strange Musician",
    "ht_twelve_brothers": "The Twelve Brothers",
    "ht_wolf_seven_kids": "The Wolf and the Seven Kids",
    "ht_youth_fear": "The Youth Who Could Not Shudder",
}

# Russian Fairy Tale Title Mappings (Afanasyev Collection)
RUSSIAN_TITLES = {
    "afanasyev_alyonushka": ("Sister Alyonushka and Brother Ivanushka", "Сестрица Алёнушка и братец Иванушка"),
    "afanasyev_baba_yaga": ("Baba Yaga", "Баба-Яга"),
    "afanasyev_baba_yaga_1": ("Baba Yaga (Part 1)", "Баба-Яга (часть 1)"),
    "afanasyev_baba_yaga_2": ("Baba Yaga (Part 2)", "Баба-Яга (часть 2)"),
    "afanasyev_demyan": ("Demyan's Fish Soup", "Демьянова уха"),
    "afanasyev_finist": ("Finist the Bright Falcon", "Финист Ясный Сокол"),
    "afanasyev_frolka": ("Frolka the Sitter", "Фролка-сидень"),
    "afanasyev_goloviha": ("Golovikha", "Головиха"),
    "afanasyev_havroshechka": ("Kroshechka-Khavroshechka", "Крошечка-Хаврошечка"),
    "afanasyev_ivan_durak": ("Ivan the Fool", "Иван-Дурак"),
    "afanasyev_ivan_marfa": ("Ivan and Marfa", "Иван и Марфа"),
    "afanasyev_ivan_popyalov": ("Ivan Popyalov", "Иван Попялов"),
    "afanasyev_kochet_kuritsa": ("The Rooster and the Hen", "Кочет и Курица"),
    "afanasyev_koschei": ("Koschei the Deathless", "Кощей Бессмертный"),
    "afanasyev_kot_petuh_lisa": ("The Cat, the Rooster, and the Fox", "Кот, Петух и Лиса"),
    "afanasyev_koza": ("The Goat", "Коза"),
    "afanasyev_kozlenochek": ("The Little Goat Kid", "Козлёночек"),
    "afanasyev_letuchiy_korabl": ("The Flying Ship", "Летучий Корабль"),
    "afanasyev_lutonyushka": ("Lutonyushka", "Лутонюшка"),
    "afanasyev_marko_bogatiy": ("Marko the Rich", "Марко Богатый"),
    "afanasyev_marya_morevna": ("Marya Morevna", "Марья Моревна"),
    "afanasyev_mena": ("The Exchange", "Мена"),
    "afanasyev_mizgir": ("The Spider", "Мизгирь"),
    "afanasyev_molodets": ("The Fine Fellow", "Молодец"),
    "afanasyev_muzhik_medved": ("The Peasant and the Bear", "Мужик и Медведь"),
    "afanasyev_nabitiy_durak": ("The Beaten Fool", "Набитый Дурак"),
    "afanasyev_ne_lyubo": ("If You Don't Like It, Don't Listen", "Не любо — не слушай"),
    "afanasyev_petushok": ("The Golden Cockerel", "Петушок — Золотой Гребешок"),
    "afanasyev_sem_simeonov": ("The Seven Simeons", "Семь Симеонов"),
    "afanasyev_sivka_burka": ("Sivka-Burka", "Сивка-Бурка"),
    "afanasyev_svinka": ("The Little Pig", "Свинка"),
    "afanasyev_tsarevna_lyagushka": ("The Frog Princess", "Царевна-Лягушка"),
    "afanasyev_tsarevna_lyagushka_v2": ("The Frog Princess (Version 2)", "Царевна-Лягушка (версия 2)"),
    "afanasyev_tsarevna_underground": ("The Underground Princess", "Подземная Царевна"),
    "afanasyev_vasilisa": ("Vasilisa the Beautiful", "Василиса Прекрасная"),
    "afanasyev_volk": ("The Wolf", "Волк"),
    "afanasyev_volk_koza": ("The Wolf and the Goat", "Волк и Коза"),
    "afanasyev_zhar_ptitsa": ("The Firebird", "Жар-Птица"),
}

# Content type mappings by category
CONTENT_TYPES = {
    "fairytales_en": "audiobook",
    "fairytales_ru": "audiobook",
    "english": "audiobook",  # will be renamed
    "russian": "audiobook",  # will be renamed
    "nature": "sounds",
    "whitenoise": "sounds",
    "ambient": "music",
    "classical": "music",
    "lullabies": "music",
    "children": "music",
    "acoustic": "music",
}


def get_story_key(filename: str) -> str:
    """Extract story identifier from filename."""
    # e.g., "fairytales/en/en_grimm_briar_rose.mp3" -> "grimm_briar_rose"
    basename = os.path.basename(filename)
    name = basename.replace(".mp3", "")
    # Remove language prefix (en_, ru_)
    if name.startswith("en_"):
        name = name[3:]
    elif name.startswith("ru_"):
        name = name[3:]
    return name


def update_english_fairytale(track: Dict[str, Any]) -> Dict[str, Any]:
    """Update English fairy tale with proper title and metadata."""
    filename = track.get("filename", "")
    story_key = get_story_key(filename)

    # Try Grimm titles first
    if story_key in GRIMM_TITLES:
        track["title"] = GRIMM_TITLES[story_key]
        track["artist"] = "Brothers Grimm"
    # Try Household Tales
    elif story_key in HT_TITLES:
        track["title"] = HT_TITLES[story_key]
        track["artist"] = "Brothers Grimm (Household Tales)"

    # Update category
    track["category"] = "fairytales_en"
    track["subcategory"] = "fairytales_en"
    track["contentType"] = "audiobook"

    # Ensure proper tags
    if "fairytales" not in track.get("tags", []):
        track["tags"] = ["fairytales", "english"]
    else:
        track["tags"] = ["fairytales", "english"]

    return track


def update_russian_fairytale(track: Dict[str, Any]) -> Dict[str, Any]:
    """Update Russian fairy tale with proper bilingual title and metadata."""
    filename = track.get("filename", "")
    story_key = get_story_key(filename)

    if story_key in RUSSIAN_TITLES:
        en_title, ru_title = RUSSIAN_TITLES[story_key]
        # Format: "English Title (Русское Название)"
        track["title"] = f"{en_title} ({ru_title})"
        track["titleEn"] = en_title
        track["titleRu"] = ru_title
        track["artist"] = "Afanasyev Collection"

    # Update category
    track["category"] = "fairytales_ru"
    track["subcategory"] = "fairytales_ru"
    track["contentType"] = "audiobook"

    # Ensure proper tags
    track["tags"] = ["fairytales", "russian"]

    return track


def update_music_or_sounds(track: Dict[str, Any]) -> Dict[str, Any]:
    """Add contentType to music and sound tracks."""
    category = track.get("category", "")

    if category in ["nature", "whitenoise"]:
        track["contentType"] = "sounds"
    else:
        track["contentType"] = "music"

    return track


def process_tracks(input_path: str, output_path: str):
    """Process all tracks and apply categorization updates."""
    with open(input_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    tracks = data.get("tracks", [])
    updated_tracks = []

    stats = {
        "english_fairytales": 0,
        "russian_fairytales": 0,
        "music": 0,
        "sounds": 0,
    }

    for track in tracks:
        category = track.get("category", "")
        filename = track.get("filename", "")

        # Check if it's a fairy tale by filename path
        if "fairytales/en/" in filename or category == "english":
            track = update_english_fairytale(track)
            stats["english_fairytales"] += 1
        elif "fairytales/ru/" in filename or category == "russian":
            track = update_russian_fairytale(track)
            stats["russian_fairytales"] += 1
        elif category in ["nature", "whitenoise"]:
            track = update_music_or_sounds(track)
            stats["sounds"] += 1
        else:
            track = update_music_or_sounds(track)
            stats["music"] += 1

        updated_tracks.append(track)

    # Update the data structure
    data["tracks"] = updated_tracks
    data["description"] = "Audio library with categorized fairy tales (EN/RU) and music/sounds"
    data["categories"] = {
        "audiobooks": ["fairytales_en", "fairytales_ru"],
        "music": ["ambient", "classical", "lullabies", "children", "acoustic"],
        "sounds": ["nature", "whitenoise"]
    }

    # Write output
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)

    print(f"✅ Processing complete!")
    print(f"   English Fairy Tales: {stats['english_fairytales']}")
    print(f"   Russian Fairy Tales: {stats['russian_fairytales']}")
    print(f"   Music Tracks: {stats['music']}")
    print(f"   Sound Tracks: {stats['sounds']}")
    print(f"   Total: {sum(stats.values())}")


if __name__ == "__main__":
    script_dir = os.path.dirname(os.path.abspath(__file__))
    audio_dir = os.path.join(script_dir, "..", "BabyInCarApp", "Resources", "Audio")

    input_path = os.path.join(audio_dir, "tracks.json")
    output_path = os.path.join(audio_dir, "tracks.json")

    if not os.path.exists(input_path):
        # Try alternate path
        input_path = os.path.join(script_dir, "..", "Resources", "Audio", "tracks.json")
        output_path = input_path

    if os.path.exists(input_path):
        process_tracks(input_path, output_path)
    else:
        print(f"Error: Could not find tracks.json at {input_path}")
        # Try from current directory structure
        alt_path = "/Users/aabyzovext/Projects/AI bussines ideas/AnticryBabyApp/BabyInCarApp/BabyInCarApp/Resources/Audio/tracks.json"
        if os.path.exists(alt_path):
            process_tracks(alt_path, alt_path)
        else:
            print(f"Also tried: {alt_path}")
