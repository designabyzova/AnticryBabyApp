# Cry Classification API

Python FastAPI service for baby cry classification using DeepInfant model preprocessing.

## Architecture

```
Web Frontend (web-cry-detector/)
        │
        ▼
   API Client (api-client.js)
        │
        ▼ HTTP POST /classify
   ┌────────────────────────────┐
   │  Cry Classification API    │
   │  (FastAPI + librosa)       │
   │                            │
   │  ┌──────────────────────┐  │
   │  │ Audio Preprocessing  │  │
   │  │ - 16kHz resampling   │  │
   │  │ - Mel-spectrogram    │  │
   │  │ - Feature extraction │  │
   │  └──────────────────────┘  │
   │            │               │
   │            ▼               │
   │  ┌──────────────────────┐  │
   │  │ Classification       │  │
   │  │ - CoreML (macOS)     │  │
   │  │ - Rule-based fallback│  │
   │  └──────────────────────┘  │
   └────────────────────────────┘
```

## Quick Start (Local Development)

### 1. Install Dependencies

```bash
cd cry-classifier-api
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
```

### 2. Run the Server

```bash
python main.py
```

Server starts at `http://localhost:8000`

### 3. Test the API

```bash
# Health check
curl http://localhost:8000/

# Classify audio file
curl -X POST -F "audio=@path/to/audio.wav" http://localhost:8000/classify
```

## API Endpoints

### `GET /`
Health check and status.

**Response:**
```json
{
  "status": "healthy",
  "model_loaded": true,
  "model_type": "rule_based"
}
```

### `POST /classify`
Classify a baby cry audio file.

**Request:**
- Content-Type: `multipart/form-data`
- Body: `audio` - WAV, MP3, or other audio file

**Response:**
```json
{
  "is_cry": true,
  "cry_confidence": 0.85,
  "cry_type": "hunger",
  "type_confidence": 0.72,
  "probabilities": {
    "hunger": 0.72,
    "tired": 0.12,
    "pain": 0.05,
    "attention": 0.06,
    "discomfort": 0.03,
    "general": 0.02
  },
  "features": {
    "pitch_mean": 420.5,
    "pitch_std": 85.2,
    "spectral_centroid_mean": 1250.3,
    "zcr_mean": 0.045,
    "onset_strength_mean": 0.65
  },
  "model_used": "rule_based"
}
```

## Using with CoreML (macOS Only)

If you have the DeepInfant V2 model and are running on macOS:

```bash
# Install CoreML support
pip install coremltools>=7.0

# Place model in project directory
cp /path/to/DeepInfant_V2.mlmodel ./

# The API will automatically detect and use the CoreML model
```

## Deployment Options

### Railway (Recommended)

1. Install Railway CLI:
```bash
npm install -g @railway/cli
railway login
```

2. Deploy:
```bash
cd cry-classifier-api
railway up
```

3. Get the deployment URL:
```bash
railway domain
```

4. Configure web frontend to use the deployed API:
```javascript
// In web-cry-detector/app.js or via URL parameter
const apiClient = new CryClassifierAPIClient({
    apiUrl: 'https://your-railway-domain.railway.app'
});
```

### Fly.io

1. Install Fly CLI:
```bash
curl -L https://fly.io/install.sh | sh
fly auth login
```

2. Create fly.toml:
```toml
app = "cry-classifier-api"

[build]
  dockerfile = "Dockerfile"

[http_service]
  internal_port = 8000
  force_https = true

[[vm]]
  cpu_kind = "shared"
  cpus = 1
  memory_mb = 512
```

3. Deploy:
```bash
fly deploy
```

### Docker (Any Platform)

```bash
# Build
docker build -t cry-classifier-api .

# Run
docker run -p 8000:8000 cry-classifier-api
```

## Web Frontend Configuration

The web frontend (`web-cry-detector/`) automatically connects to `http://localhost:8000` in development.

For production, set the API URL:

**Option 1: URL Parameter**
```
http://your-frontend.com/?api=https://your-api-url.com
```

**Option 2: Modify api-client.js**
```javascript
const apiClient = new CryClassifierAPIClient({
    apiUrl: 'https://your-production-api.railway.app'
});
```

## Feature Extraction Details

The API extracts these audio features for classification:

| Feature | Description | Cry Indicator |
|---------|-------------|---------------|
| Pitch (F0) | Fundamental frequency | 250-600 Hz for infants |
| Spectral Centroid | "Brightness" of sound | Higher in pain cries |
| ZCR | Zero-crossing rate | Varies by cry type |
| Onset Strength | Attack/intensity | Fast for pain, slow for tired |

## Troubleshooting

### "librosa not found"
```bash
pip install librosa soundfile
```

### "Audio file could not be processed"
- Ensure the file is a valid audio format (WAV, MP3, OGG)
- Check file is not corrupted
- Try converting to WAV: `ffmpeg -i input.mp3 output.wav`

### "CoreML model not loading"
- CoreML only works on macOS
- Ensure coremltools is installed: `pip install coremltools`
- Check model file exists and is not corrupted

### CORS errors from frontend
The API includes CORS middleware for all origins. If issues persist:
```python
# In main.py, verify CORSMiddleware is configured
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)
```

## Development

### Running Tests
```bash
pip install pytest httpx
pytest tests/
```

### Code Structure
```
cry-classifier-api/
├── main.py           # FastAPI app, routes, classification logic
├── requirements.txt  # Python dependencies
├── Dockerfile        # Container configuration
├── railway.json      # Railway deployment config
└── README.md         # This file
```
