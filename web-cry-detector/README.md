# Baby Cry Type Detector - Web Test Interface

A browser-based testing interface for baby cry type detection, simulating the DeepInfant V2 model behavior.

## Features

- **Real-time audio capture** from microphone using Web Audio API
- **Audio visualization** with waveform and frequency display
- **Cry type classification** into 6 categories:
  - 🍼 Hunger - rhythmic, repetitive cry
  - 😴 Tired - whiny, fussy cry that builds up
  - 😣 Pain - sudden, high-pitched, intense cry
  - 👋 Attention - intermittent, stops when attended
  - 😖 Discomfort - irregular, squirming sounds
  - 😢 General - doesn't fit other categories
- **Probability distribution** visualization
- **Classification history** tracking
- **Audio file upload** support for testing with recordings
- **Demo mode** (press 'D') for testing without microphone

## Quick Start

1. **Start a local server**:
   ```bash
   # Using Python 3
   cd web-cry-detector
   python3 -m http.server 8080

   # Or using Node.js
   npx serve

   # Or using PHP
   php -S localhost:8080
   ```

2. **Open in browser**: Navigate to `http://localhost:8080`

3. **Grant microphone permission** when prompted

4. **Click "Start Detection"** to begin analyzing audio

## Technical Details

### Audio Processing
- Sample rate: 16kHz (matching DeepInfant V2)
- Buffer size: 15,600 samples (~975ms per classification)
- Features extracted:
  - Spectral centroid
  - Spectral rolloff
  - Zero crossing rate
  - RMS energy
  - Harmonicity
  - Attack time

### Classification
The web version uses audio feature analysis to classify cry types. Unlike the iOS app which uses the trained DeepInfant V2 CoreML model, this web interface uses heuristic rules based on audio features:

| Feature | Hunger | Tired | Pain | Attention | Discomfort |
|---------|--------|-------|------|-----------|------------|
| Spectral Centroid | 400-800Hz | 300-600Hz | 600-1200Hz | 350-700Hz | 400-900Hz |
| Intensity | Medium | Low-Medium | High | Medium | Medium-High |
| Rhythmicity | High | Low-Medium | Low | Low-Medium | Low |
| Attack Time | Medium | Slow | Fast | Medium | Medium |

### Minimum Confidence Threshold
Classifications below 70% confidence are marked as "Low confidence" and not added to history.

## Demo Mode

Press **'D'** key to toggle demo mode, which:
- Generates random classifications every 3 seconds
- Simulates waveform visualization
- Useful for testing UI without microphone access

## File Structure

```
web-cry-detector/
├── index.html          # Main HTML page
├── styles.css          # UI styling
├── audio-processor.js  # Web Audio API handling
├── cry-classifier.js   # Classification logic
├── app.js              # Main application
└── README.md           # This file
```

## Browser Support

- Chrome/Edge 80+
- Firefox 76+
- Safari 14.1+

Requires:
- Web Audio API
- MediaDevices API (getUserMedia)
- ES6+ JavaScript

## Limitations

1. **Not a trained model**: Uses heuristic feature matching, not a neural network
2. **Microphone required**: Browser must have microphone permission
3. **HTTPS required**: Microphone access requires secure context (localhost or HTTPS)
4. **Accuracy**: Web version is for testing/demonstration only; iOS app uses trained CoreML model

## Development

To modify the classification parameters, edit `cry-classifier.js`:

```javascript
this.featureProfiles = {
    hunger: {
        spectralCentroid: { min: 400, max: 800, weight: 0.3 },
        // ... adjust parameters
    },
    // ... other cry types
};
```

## License

Part of the Lulla Baby Cry Soother application.
