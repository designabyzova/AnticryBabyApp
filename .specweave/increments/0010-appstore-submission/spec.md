# App Store Submission - Build, Screenshots & Submit

## Overview
Complete App Store submission package for BabyInCar app including app build, screenshots, metadata, and submission via CLI tools.

## User Stories

### US-001: Generate App Icon
**As a** developer preparing for App Store
**I want** proper app icons in all required sizes
**So that** the app meets App Store requirements

#### Acceptance Criteria
- [ ] AC-US1-01: Generate 1024x1024 iOS app icon
- [ ] AC-US1-02: Export all required icon sizes to Assets.xcassets
- [ ] AC-US1-03: Verify icon renders correctly at all sizes

### US-002: Build Release Archive
**As a** developer
**I want** to build a release archive
**So that** I can submit to App Store Connect

#### Acceptance Criteria
- [ ] AC-US2-01: Build succeeds with Release configuration
- [ ] AC-US2-02: Archive created successfully
- [ ] AC-US2-03: Archive passes validation

### US-003: Generate App Store Screenshots
**As a** app publisher
**I want** screenshots for all required device sizes
**So that** the app listing looks professional

#### Acceptance Criteria
- [ ] AC-US3-01: iPhone 6.9" (iPhone 16 Pro Max) - 1320x2868
- [ ] AC-US3-02: iPhone 6.7" (iPhone 15 Pro Max) - 1290x2796
- [ ] AC-US3-03: iPhone 6.5" (iPhone 11 Pro Max) - 1242x2688
- [ ] AC-US3-04: iPhone 5.5" (iPhone 8 Plus) - 1242x2208
- [ ] AC-US3-05: iPad Pro 12.9" - 2048x2732

### US-004: Prepare App Store Metadata
**As a** app publisher
**I want** complete app metadata
**So that** the listing is compelling and discoverable

#### Acceptance Criteria
- [ ] AC-US4-01: App name (max 30 chars)
- [ ] AC-US4-02: Subtitle (max 30 chars)
- [ ] AC-US4-03: Description (max 4000 chars)
- [ ] AC-US4-04: Keywords (max 100 chars)
- [ ] AC-US4-05: Support URL
- [ ] AC-US4-06: Privacy Policy URL
- [ ] AC-US4-07: Category selection
- [ ] AC-US4-08: Age rating questionnaire answers

### US-005: Submit to App Store Connect
**As a** developer
**I want** to submit via CLI
**So that** the process is automated

#### Acceptance Criteria
- [ ] AC-US5-01: Upload build to App Store Connect
- [ ] AC-US5-02: Configure app metadata in ASC
- [ ] AC-US5-03: Submit for review

## App Store Metadata (Ready to Use)

### Basic Info
- **App Name**: Baby in Car
- **Subtitle**: Soothe Your Baby with AI
- **Bundle ID**: com.babyincar.app
- **Version**: 1.0.0
- **Category**: Health & Fitness (Primary), Lifestyle (Secondary)
- **Age Rating**: 4+

### Description (English)
Baby in Car is the most advanced baby soothing app powered by AI. Our unique cry detection technology automatically plays calming sounds when your baby starts crying, making car rides peaceful for the whole family.

**Key Features:**

🎵 **Smart Cry Detection** - AI-powered system detects baby cries and automatically responds with soothing sounds

🧒 **Baby Mood Intelligence** - Learns your baby's unique preferences over time for personalized recommendations

🎧 **Premium Sound Library** - Lullabies, white noise, nature sounds, classical music, and more

📱 **CarPlay Integration** - Full CarPlay support for safe, distraction-free driving

🗣️ **AI Chatbot** - Ask questions about baby sleep and get research-backed answers

✨ **"It Helped!" Tracking** - Track what works for your baby to build a personalized soothing profile

**Sound Categories:**
- White Noise (car engine, vacuum, dryer)
- Nature (rain, ocean, forest)
- Lullabies (Brahms, Twinkle Twinkle, Mozart)
- Classical (Chopin, Debussy, Satie)
- Ambient (drones, choirs)
- Russian Fairy Tales
- Podcasts for Parents

**Why Parents Love Us:**
- Hands-free operation while driving
- Works offline once downloaded
- Scientifically-backed soothing sounds
- Beautiful, calming interface
- Privacy-first - no data leaves your device

Download now and enjoy peaceful car rides with your little one!

### Keywords
baby sleep,cry detection,white noise,lullaby,soothing,newborn,infant,car seat,carplay,baby music,baby sounds,calm baby,sleep sounds,baby calm

### Promotional Text
AI-powered baby soothing for peaceful car rides. Cry detection automatically plays calming sounds!

### Privacy Policy URL
https://babyincar.app/privacy

### Support URL
https://babyincar.app/support

### Marketing URL
https://babyincar.app

## Age Rating Questionnaire

- Cartoon or Fantasy Violence: None
- Realistic Violence: None
- Prolonged Graphic or Sadistic Violence: None
- Profanity or Crude Humor: None
- Mature/Suggestive Themes: None
- Horror/Fear Themes: None
- Medical/Treatment Information: None
- Alcohol, Tobacco, or Drug Use: None
- Simulated Gambling: None
- Sexual Content or Nudity: None
- Unrestricted Web Access: No
- Gambling and Contests: None

**Result: 4+ (All Ages)**

## Required Device Permissions

1. **Microphone** - For cry detection and voice commands
2. **Speech Recognition** - For hands-free voice control
3. **Photo Library** - For baby profile pictures (optional)
4. **Camera** - For taking baby profile pictures (optional)
5. **Background Audio** - For continuous playback

## Screenshot Content Strategy

### Screen 1: Hero Shot
- Baby sleeping peacefully in car seat
- App player view showing current track
- Text: "Soothe Your Baby Instantly"

### Screen 2: Cry Detection
- Cry detection view with waveform
- Alert showing "Crying Detected"
- Text: "AI-Powered Cry Detection"

### Screen 3: Sound Library
- Library view with category cards
- Multiple sound options visible
- Text: "100+ Premium Sounds"

### Screen 4: CarPlay
- CarPlay interface mockup
- Now playing screen
- Text: "Perfect for Driving"

### Screen 5: Personalization
- Baby mood dashboard
- "It Helped!" buttons
- Text: "Learns What Works"

### Screen 6: AI Chatbot
- Chat interface with question
- Research-backed response
- Text: "Ask the AI Expert"
