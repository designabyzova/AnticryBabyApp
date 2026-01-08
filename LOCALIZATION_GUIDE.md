# 🌍 BabyInCarApp Localization Guide

## Overview

The BabyInCarApp now supports **10 languages** with professional, native translations for all user-facing strings.

### Supported Languages

| Language | Code | Flag | Native Name | RTL Support |
|----------|------|------|-------------|-------------|
| English | `en` | 🇬🇧 | English | No |
| Russian | `ru` | 🇷🇺 | Русский | No |
| Spanish | `es` | 🇪🇸 | Español | No |
| French | `fr` | 🇫🇷 | Français | No |
| German | `de` | 🇩🇪 | Deutsch | No |
| Chinese (Simplified) | `zh-Hans` | 🇨🇳 | 简体中文 | No |
| Japanese | `ja` | 🇯🇵 | 日本語 | No |
| Portuguese | `pt` | 🇵🇹 | Português | No |
| Arabic | `ar` | 🇸🇦 | العربية | **Yes** |
| Italian | `it` | 🇮🇹 | Italiano | No |

## Architecture

### Files Structure

```
BabyInCarApp/
├── Localizable.xcstrings           # Main localization catalog (780+ translations)
├── Extensions/
│   └── Localization.swift          # Helper utilities and L10n enum
├── Views/
│   └── LanguageSelectionView.swift # Language picker UI
└── generate_localizations.py       # Script to regenerate xcstrings
```

### Translation Categories

The localization system is organized into logical categories:

1. **Navigation** (`nav.*`) - Tab bars, navigation titles
2. **Buttons** (`button.*`) - Action buttons
3. **Home** (`home.*`) - Home screen greetings and messages
4. **Emergency** (`emergency.*`) - Cry detection strings
5. **Cry Types** (`cry.*`) - Hunger, tired, pain, etc.
6. **Player** (`player.*`) - Music player interface
7. **Empty States** (`empty.*`) - No content messages
8. **Categories** (`category.*`) - Content categories
9. **Settings** (`settings.*`) - Settings screen
10. **Onboarding** (`onboarding.*`) - First-run experience
11. **Premium** (`premium.*`) - Subscription messaging
12. **Time** (`time.*`) - Duration formatting
13. **Actions** (`action.*`) - Context menu actions
14. **Alerts** (`alert.*`) - Alert dialogs
15. **Status** (`status.*`) - Loading states
16. **Insights** (`insights.*`) - Analytics screen
17. **Baby** (`baby.*`) - Baby profile fields
18. **Search** (`search.*`) - Search interface

## Usage

### Type-Safe Localization

Use the `L10n` enum for compile-time safety:

```swift
import SwiftUI

struct MyView: View {
    var body: some View {
        VStack {
            // Navigation title
            Text(L10n.Nav.profile)

            // Button
            Button(L10n.Button.play) {
                // Action
            }

            // Greeting based on time of day
            Text(L10n.Home.Greeting.morning)

            // Empty state
            Text(L10n.Empty.noFavorites)
                .foregroundStyle(.secondary)
        }
        .navigationTitle(L10n.Nav.library)
    }
}
```

### Direct String Localization

For strings not in the catalog (rare):

```swift
// Simple localization
let text = "some.key".localized

// With arguments
let message = "user.greeting".localized("John")
```

### Navigation Titles

```swift
.navigationTitle(L10n.Nav.favorites)
.navigationTitle(L10n.Nav.library)
.navigationTitle(L10n.Nav.search)
```

### Buttons

```swift
// Primary actions
Button(L10n.Button.play) { }
Button(L10n.Button.pause) { }
Button(L10n.Button.save) { }
Button(L10n.Button.cancel) { }

// Upgrade button
Button(L10n.Button.upgrade) { }
```

### Greetings (Time-Aware)

```swift
var greeting: LocalizedStringKey {
    let hour = Calendar.current.component(.hour, from: Date())
    switch hour {
    case 5..<12: return L10n.Home.Greeting.morning
    case 12..<17: return L10n.Home.Greeting.afternoon
    case 17..<21: return L10n.Home.Greeting.evening
    default: return L10n.Home.Greeting.night
    }
}

Text(greeting)
    .font(.largeTitle.bold())
```

### Empty States

```swift
VStack(spacing: 16) {
    Image(systemName: "heart.slash")
        .font(.system(size: 48))
        .foregroundStyle(.secondary)

    Text(L10n.Empty.noFavorites)
        .font(.title3)
        .foregroundStyle(.secondary)
}
```

### Categories

```swift
ForEach(categories) { category in
    Text(category.localizedName)
}

extension AudioCategory {
    var localizedName: LocalizedStringKey {
        switch self {
        case .lullabies: return L10n.Category.lullabies
        case .classical: return L10n.Category.classical
        case .nature: return L10n.Category.nature
        case .fairyTales: return L10n.Category.fairyTales
        case .ambient: return L10n.Category.ambient
        }
    }
}
```

### Status Messages

```swift
// Loading state
Text(L10n.Status.loading)
    .foregroundStyle(.secondary)

// Downloading
HStack {
    ProgressView()
    Text(L10n.Status.downloading)
}
```

### Alerts

```swift
.alert(L10n.Alert.deletePlaylist, isPresented: $showingAlert) {
    Button(L10n.Button.cancel, role: .cancel) { }
    Button(L10n.Button.delete, role: .destructive) {
        deletePlaylist()
    }
}
```

## Language Selection

### Add to Settings/Profile

```swift
struct ProfileView: View {
    @State private var showingLanguageSelection = false

    var body: some View {
        List {
            Section {
                Button {
                    showingLanguageSelection = true
                } label: {
                    HStack {
                        Label(L10n.Settings.languages, systemImage: "globe")
                        Spacer()
                        Text(LanguageManager.shared.currentLanguage.displayName)
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .sheet(isPresented: $showingLanguageSelection) {
            LanguageSelectionView()
        }
    }
}
```

### Language Manager

Access the current language anywhere:

```swift
@StateObject private var languageManager = LanguageManager.shared

// Get current language
let currentLang = languageManager.currentLanguage

// Change language
languageManager.setLanguage(.spanish)

// Check if RTL
if languageManager.currentLanguage.isRTL {
    // Apply RTL layout
}
```

## RTL (Right-to-Left) Support

### Automatic RTL

Apply RTL automatically based on language:

```swift
struct MyView: View {
    var body: some View {
        VStack {
            // Content
        }
        .applyRTL()  // Automatically applies RTL for Arabic
    }
}
```

### Manual RTL Check

```swift
if LanguageManager.shared.currentLanguage.isRTL {
    // Arabic-specific layout adjustments
    HStack(spacing: 16) {
        Text("Content")
        Spacer()
        Image(systemName: "chevron.left")  // Flipped automatically
    }
}
```

### FlippedUnevenly Modifier

For icons that should NOT flip in RTL:

```swift
Image(systemName: "heart.fill")
    .flipsForRightToLeftLayoutDirection(false)
```

## Adding New Strings

### Step 1: Update Translation Dictionary

Edit `generate_localizations.py`:

```python
TRANSLATIONS = {
    # ... existing translations ...

    "new.key": {
        "en": "New String",
        "ru": "Новая строка",
        "es": "Nueva cadena",
        "fr": "Nouvelle chaîne",
        "de": "Neue Zeichenfolge",
        "zh-Hans": "新字符串",
        "ja": "新しい文字列",
        "pt": "Nova string",
        "ar": "سلسلة جديدة",
        "it": "Nuova stringa"
    }
}
```

### Step 2: Regenerate Localizable.xcstrings

```bash
python3 generate_localizations.py
```

### Step 3: Add to L10n Enum

Edit `Extensions/Localization.swift`:

```swift
enum L10n {
    // ... existing enums ...

    enum New {
        static let key = LocalizedStringKey("new.key")
    }
}
```

### Step 4: Use in Views

```swift
Text(L10n.New.key)
```

## Testing

### Test All Languages

1. **Xcode Scheme Editor**:
   - Product > Scheme > Edit Scheme
   - Run > Options > App Language
   - Select each language and test

2. **Simulator Settings**:
   - Settings > General > Language & Region
   - Change language
   - Restart app

### Test RTL (Arabic)

1. Set language to Arabic
2. Verify text alignment (right-aligned)
3. Check navigation (back button on right)
4. Test swipe gestures (reversed)

### Visual Testing Checklist

- [ ] Navigation titles localized
- [ ] Buttons localized
- [ ] Empty states localized
- [ ] Alerts localized
- [ ] Time/date formats correct
- [ ] No truncated text
- [ ] RTL layout correct (Arabic)
- [ ] Icons flip appropriately

## Best Practices

### DO ✅

- Use `L10n` enum for type safety
- Add context comments for translators
- Test with longest language (German often longest)
- Use `.lineLimit(nil)` for dynamic text
- Handle pluralization properly
- Test RTL thoroughly for Arabic

### DON'T ❌

- Hardcode strings in views
- Concatenate localized strings
- Assume text length
- Forget to test all languages
- Use English-centric layouts
- Skip RTL testing

## Migration Guide

### Updating Existing Views

**Before:**
```swift
Text("Profile")
Button("Save") { }
.navigationTitle("Library")
```

**After:**
```swift
Text(L10n.Nav.profile)
Button(L10n.Button.save) { }
.navigationTitle(L10n.Nav.library)
```

### Search & Replace Patterns

Common hardcoded strings to replace:

```swift
// Navigation
"Profile" → L10n.Nav.profile
"Favorites" → L10n.Nav.favorites
"Library" → L10n.Nav.library
"Search" → L10n.Nav.search

// Buttons
"Play" → L10n.Button.play
"Pause" → L10n.Button.pause
"Save" → L10n.Button.save
"Cancel" → L10n.Button.cancel

// Empty states
"No favorites yet" → L10n.Empty.noFavorites
"No playlists yet" → L10n.Empty.noPlaylists
```

## Statistics

- **Total Languages**: 10
- **Total Translation Keys**: 78
- **Total Translations**: 780
- **Categories**: 18
- **RTL Languages**: 1 (Arabic)
- **Files Created**: 3
  - `Localizable.xcstrings`
  - `Extensions/Localization.swift`
  - `Views/LanguageSelectionView.swift`

## Maintenance

### Regular Tasks

1. **Weekly**: Check for new hardcoded strings
2. **Per Release**: Run full language testing
3. **Per Feature**: Add translations immediately
4. **Monthly**: Review translation quality

### Tools

- **Xcode String Catalog Editor**: Visual translation editor
- **generate_localizations.py**: Regenerate from source
- **iOS Simulator**: Test all languages

## Resources

- [Apple Localization Guide](https://developer.apple.com/localization/)
- [WWDC Videos on Localization](https://developer.apple.com/videos/)
- [Unicode CLDR](https://cldr.unicode.org/) - Cultural conventions
- [RTL Guidelines](https://developer.apple.com/design/human-interface-guidelines/right-to-left)

## Support

For translation issues or new language requests, contact the development team.

---

**Last Updated**: 2026-01-08
**Version**: 1.0.0
**Languages**: 10 (EN, RU, ES, FR, DE, ZH-Hans, JA, PT, AR, IT)
