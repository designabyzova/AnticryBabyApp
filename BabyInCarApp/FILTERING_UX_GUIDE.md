# Filter UX Design Guide

## Visual Hierarchy

```
┌─────────────────────────────────────────────────────────────────┐
│  Classical Music                                   [⋯ Menu]      │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│                    [Category Icon]                                │
│                   Classical Music                                 │
│                     24 tracks                                     │
│                                                                   │
├─────────────────────────────────────────────────────────────────┤
│  Quick Picks (Presets)                                           │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐                 │
│  │ 🎹         │  │ 🌙         │  │ ⚡         │                 │
│  │ Classical  │  │ Newborn    │  │ Quick      │  →              │
│  │ Piano      │  │ Bedtime    │  │ Calm       │                 │
│  │ 3 filters  │  │ 3 filters  │  │ 2 filters  │                 │
│  └────────────┘  └────────────┘  └────────────┘                 │
├─────────────────────────────────────────────────────────────────┤
│  Active Filters: Classical • Piano • 0-3 months                  │
│  [✕ Clear 3 filters]                              [⤺ Undo]      │
├─────────────────────────────────────────────────────────────────┤
│  Top Filters (Horizontal Scroll)                                │
│  [Piano ✓ 12] [Guitar 8] [Orchestra 6] [Voice 4] →              │
├─────────────────────────────────────────────────────────────────┤
│  [⚙ More Filters...]                                             │
├─────────────────────────────────────────────────────────────────┤
│  Track Grid (12 results)                                         │
│  ┌───────┐  ┌───────┐                                            │
│  │ 🎵    │  │ 🎵    │  ...                                       │
│  │ Track │  │ Track │                                            │
│  └───────┘  └───────┘                                            │
└─────────────────────────────────────────────────────────────────┘
```

---

## Advanced Filter Sheet

```
┌─────────────────────────────────────────────────────────────────┐
│  [Done]                Filters                      [Clear]      │
├─────────────────────────────────────────────────────────────────┤
│  Quick Picks                                                     │
│  [Preset Cards - same as main view]                             │
├─────────────────────────────────────────────────────────────────┤
│  📂 Category                                           ●1         │
│  [Classical ✓ 24] [Lullabies 18] [Nature 12] →                  │
│                                                                   │
│  🎸 Instrument                                         ●2         │
│  [Piano ✓ 12] [Guitar ✓ 8] [Orchestra 6] [Violin 4] →          │
│                                                                   │
│  😊 Mood                                                          │
│  [Calming 18] [Soothing 15] [Playful 6] →                       │
│                                                                   │
│  🎵 Tempo                                                         │
│  [Slow 20] [Medium 8] [Fast 2] →                                │
│                                                                   │
│  🌍 Language                                                      │
│  [🇺🇸 English 10] [🇷🇺 Russian 8] [🇪🇸 Spanish 4] →              │
│                                                                   │
│  👶 Age Range                                          ●1         │
│  [0-3 months ✓ 8] [3-6 months 12] [6-12 months 18] →            │
│                                                                   │
│  ⏱ Duration                                                       │
│  [Short 6] [Medium 14] [Long 4] →                               │
│                                                                   │
│  💗 Calming Level                                                 │
│  [Very Calming 15] [Calming 7] [Moderate 2] →                   │
│                                                                   │
├─────────────────────────────────────────────────────────────────┤
│                      [12 results]                                │
└─────────────────────────────────────────────────────────────────┘
```

---

## Filter Chip States

### 1. Unselected Chip
```
┌─────────────────┐
│ 🎹 Piano    12  │  ← Gray background, black text, count badge
└─────────────────┘
```

### 2. Selected Chip
```
┌─────────────────┐
│ 🎹 Piano 12  ✓  │  ← Gradient background, white text, checkmark
└─────────────────┘
   Shadow + Glow
```

### 3. Premium Locked Preset
```
┌─────────────────┐
│ 🔒             │
│ Bedtime Stories │  ← Dimmed gradient, lock icon
│ English tales   │
│ 3 filters       │
└─────────────────┘
  60% opacity
```

---

## Interaction Patterns

### Filter Selection Flow

```
User taps "Piano" chip
       ↓
Haptic feedback (light)
       ↓
Chip animates (scale 0.95 → 1.0)
       ↓
Chip background changes to gradient
       ↓
Checkmark appears
       ↓
Track count updates dynamically
       ↓
Filtered tracks refresh
       ↓
Active filter summary updates
```

### Preset Application Flow

```
User taps "Classical Piano" preset
       ↓
Haptic feedback (medium)
       ↓
Previous filter state saved (for undo)
       ↓
All 3 preset tags applied
       ↓
Active filter summary shows preset name
       ↓
Tracks filter instantly
       ↓
Sheet auto-closes (if in sheet)
```

### Reset Flow

```
User taps "Clear 3 filters"
       ↓
Haptic feedback (medium)
       ↓
Previous state saved
       ↓
All filters cleared
       ↓
"Undo" button appears
       ↓
5-second timer starts
       ↓
All tracks shown
       ↓
(If undo tapped) → Filters restored
       ↓
(If timeout) → Undo button fades out
```

---

## Color Palette

### Filter Chip Colors (by tag type)

| Type | Gradient Start | Gradient End | Icon |
|------|----------------|--------------|------|
| **Category** | `#3B82F6` (Blue) | `#60A5FA` | 📂 |
| **Subcategory** | `#A855F7` (Purple) | `#C084FC` | 🏷️ |
| **Instrument** | `#F97316` (Orange) | `#FB923C` | 🎸 |
| **Mood** | `#EC4899` (Pink) | `#F472B6` | 😊 |
| **Tempo** | `#10B981` (Green) | `#34D399` | 🎵 |
| **Theme** | `#FBBF24` (Yellow) | `#FCD34D` | ✨ |
| **Language** | `#6366F1` (Indigo) | `#818CF8` | 🌍 |
| **Age Range** | `#06B6D4` (Cyan) | `#22D3EE` | 👶 |
| **Duration** | `#14B8A6` (Teal) | `#2DD4BF` | ⏱ |
| **Calming Level** | `#FF6B9D` | `#FF8FB3` | 💗 |

### State Colors

- **Unselected**: `systemGray6` background
- **Selected**: Gradient (per tag type)
- **Pressed**: 95% scale, reduced shadow
- **Count Badge**: `systemGray5` (unselected), `white.opacity(0.3)` (selected)

---

## Typography

| Element | Font | Weight | Size |
|---------|------|--------|------|
| **Chip Label** | System | Medium | 14pt |
| **Chip Selected** | System | Semibold | 14pt |
| **Count Badge** | System | Bold | 11pt |
| **Section Header** | System | Bold | 15pt |
| **Active Count Badge** | System | Bold | 12pt |
| **Preset Title** | System | Bold | 16pt |
| **Preset Description** | System | Regular | 13pt |
| **Filter Summary** | System | Semibold | 14pt |
| **Results Count** | System | Semibold | 15pt |

---

## Spacing & Layout

### Filter Chip Bar
- **Horizontal padding**: 20pt
- **Vertical padding**: 8pt
- **Chip spacing**: 10pt
- **Chip horizontal padding**: 14pt
- **Chip vertical padding**: 8pt

### Grouped Filter Sections
- **Section spacing**: 20pt
- **Header padding**: 20pt horizontal
- **Header to chips**: 10pt vertical
- **Active count badge**: 20×20pt circle

### Preset Cards
- **Card size**: 160×140pt
- **Card spacing**: 16pt
- **Card padding**: 16pt
- **Card corner radius**: 16pt

### Filter Sheet
- **Section spacing**: 24pt
- **Bottom padding**: 100pt (for results count)
- **Results badge padding**: 24pt horizontal, 14pt vertical

---

## Animations

### Chip Selection
```swift
.scaleEffect(isPressed ? 0.95 : 1.0)
.animation(.spring(response: 0.3, dampingFraction: 0.6))
```

### Reset/Undo Buttons
```swift
.transition(.scale.combined(with: .opacity))
.animation(.spring(response: 0.4, dampingFraction: 0.7))
```

### Track Grid Refresh
```swift
.animation(.easeInOut(duration: 0.3), value: filteredTracks)
```

---

## Accessibility

### VoiceOver Labels

| Element | Label |
|---------|-------|
| Chip (unselected) | "Piano, 12 tracks, double tap to filter" |
| Chip (selected) | "Piano, selected, 12 tracks, double tap to remove filter" |
| Preset Card | "Classical Piano preset, 3 filters, double tap to apply" |
| Reset Button | "Clear 3 filters, double tap to reset" |
| Undo Button | "Undo filter change, double tap to restore" |

### Dynamic Type Support

All text scales with user's preferred font size using:
```swift
.font(.system(size: 14, weight: .medium))
```

### Color Contrast

- **Minimum contrast**: 4.5:1 (WCAG AA)
- **Chip text on gradient**: White (always readable)
- **Count badges**: High contrast against background

---

## Performance Best Practices

### Lazy Loading
- **Chips**: Rendered on-demand in ScrollView
- **Tracks**: LazyVGrid for efficient rendering
- **Counts**: Computed only when filters change

### Debouncing
- **Filter changes**: Apply immediately (no debounce needed)
- **Track counting**: Batched with filter application

### Caching
- **Tag extraction**: Cached in FilterViewModel
- **Track counts**: Updated only when selectedTags changes
- **Preset results**: Computed lazily

---

## Edge Cases

### No Results
```
┌─────────────────────────────────────────────┐
│  No tracks match your filters              │
│                                             │
│  Try removing some filters or              │
│  selecting a Quick Pick                    │
│                                             │
│  [Clear Filters]                            │
└─────────────────────────────────────────────┘
```

### All Filters Same Type
```
User selects: Piano, Guitar, Orchestra (all instruments)
Logic: Show tracks with (Piano OR Guitar OR Orchestra)
NOT: Show tracks with all three instruments
```

### Premium Content Locked
```
[Preset Card with 🔒]
On tap → No action (visual feedback only)
Show tooltip: "Premium subscription required"
```

### Offline Mode
```
Some tags (origin, author, collection) require API
If offline → Hide API-dependent tag types
Show toast: "Some filters unavailable offline"
```

---

## Summary Checklist

**Filter System Features:**

✅ 13 tag types for multi-dimensional discovery
✅ Smart multi-select (AND within types, OR across types)
✅ Dynamic track counting
✅ 5 pre-configured presets
✅ Undo/redo with 5-second timeout
✅ Premium gating integration
✅ Haptic feedback on all actions
✅ Smooth animations (60 FPS)
✅ VoiceOver labels
✅ Dynamic Type support
✅ Offline resilience
✅ Performance optimized (<30ms)

**UI Components:**

✅ FilterChipView - Single chip with selection state
✅ FilterChipBar - Horizontal scrollable chip row
✅ GroupedFilterView - Organized sections by tag type
✅ FilterResetButton - Smart reset with undo
✅ FilterPresetSection - Quick Picks carousel
✅ CategoryDetailView - Full integration example

**Documentation:**

✅ Architecture overview
✅ Integration guide
✅ UX design guide (this doc)
✅ Performance metrics
✅ Accessibility guidelines
