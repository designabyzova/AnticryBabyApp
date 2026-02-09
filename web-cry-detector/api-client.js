/**
 * API Client for Cry Classification Backend
 *
 * Sends audio to Python backend for DeepInfant model classification.
 * Falls back to client-side classification if API is unavailable.
 */

class CryClassifierAPIClient {
    constructor(options = {}) {
        // API endpoint - configure via environment or default to local
        this.apiUrl = options.apiUrl || 'http://localhost:8000';

        // Track API availability
        this.apiAvailable = null; // null = not checked, true/false = result

        // Callback for status updates
        this.onStatusChange = options.onStatusChange || null;

        console.log(`[APIClient] Initialized with API URL: ${this.apiUrl}`);
    }

    /**
     * Check if the API is available
     */
    async checkHealth() {
        try {
            const response = await fetch(`${this.apiUrl}/`, {
                method: 'GET',
                headers: { 'Accept': 'application/json' },
            });

            if (response.ok) {
                const data = await response.json();
                this.apiAvailable = true;
                console.log('[APIClient] API is healthy:', data);

                if (this.onStatusChange) {
                    this.onStatusChange({
                        available: true,
                        modelLoaded: data.model_loaded,
                        modelType: data.model_type
                    });
                }

                return data;
            }

            this.apiAvailable = false;
            return null;

        } catch (error) {
            console.warn('[APIClient] API health check failed:', error);
            this.apiAvailable = false;

            if (this.onStatusChange) {
                this.onStatusChange({
                    available: false,
                    error: error.message
                });
            }

            return null;
        }
    }

    /**
     * Convert Float32Array audio samples to WAV format
     */
    samplesToWav(samples, sampleRate = 16000) {
        const buffer = new ArrayBuffer(44 + samples.length * 2);
        const view = new DataView(buffer);

        // WAV header
        const writeString = (offset, string) => {
            for (let i = 0; i < string.length; i++) {
                view.setUint8(offset + i, string.charCodeAt(i));
            }
        };

        writeString(0, 'RIFF');
        view.setUint32(4, 36 + samples.length * 2, true);
        writeString(8, 'WAVE');
        writeString(12, 'fmt ');
        view.setUint32(16, 16, true);                    // Subchunk1Size
        view.setUint16(20, 1, true);                     // AudioFormat (PCM)
        view.setUint16(22, 1, true);                     // NumChannels
        view.setUint32(24, sampleRate, true);           // SampleRate
        view.setUint32(28, sampleRate * 2, true);       // ByteRate
        view.setUint16(32, 2, true);                     // BlockAlign
        view.setUint16(34, 16, true);                    // BitsPerSample
        writeString(36, 'data');
        view.setUint32(40, samples.length * 2, true);   // Subchunk2Size

        // Audio data
        const floatTo16BitPCM = (sample) => {
            const s = Math.max(-1, Math.min(1, sample));
            return s < 0 ? s * 0x8000 : s * 0x7FFF;
        };

        let offset = 44;
        for (let i = 0; i < samples.length; i++) {
            view.setInt16(offset, floatTo16BitPCM(samples[i]), true);
            offset += 2;
        }

        return new Blob([buffer], { type: 'audio/wav' });
    }

    /**
     * Classify audio samples via API
     */
    async classify(samples, sampleRate = 16000) {
        // Check API availability if not yet checked
        if (this.apiAvailable === null) {
            await this.checkHealth();
        }

        // If API unavailable, return null (caller should use fallback)
        if (!this.apiAvailable) {
            console.log('[APIClient] API unavailable, use fallback classification');
            return null;
        }

        try {
            // Convert samples to WAV
            const wavBlob = this.samplesToWav(samples, sampleRate);

            // Create form data
            const formData = new FormData();
            formData.append('audio', wavBlob, 'audio.wav');

            // Send to API
            const response = await fetch(`${this.apiUrl}/classify`, {
                method: 'POST',
                body: formData,
            });

            if (!response.ok) {
                const errorText = await response.text();
                throw new Error(`API error: ${response.status} - ${errorText}`);
            }

            const result = await response.json();
            console.log('[APIClient] Classification result:', result);

            // Transform API response to match expected format
            return {
                // Stage 1: Cry detection
                detection: {
                    isCry: result.is_cry,
                    confidence: result.cry_confidence,
                    isHighConfidence: result.cry_confidence >= 0.7,
                    scores: {
                        f0InRange: result.features?.pitch_mean > 250 && result.features?.pitch_mean < 600 ? 1.0 : 0.5,
                        harmonicEnergy: 0.5, // Not directly available
                        cryFormants: 0.5,
                        temporalVariation: 0.5,
                        antiMusicScore: 0.8
                    },
                    inferenceTime: 0, // Not tracked by API
                    timestamp: new Date()
                },

                // Stage 2: Cry type classification
                classification: result.is_cry ? {
                    cryType: result.cry_type || 'general',
                    confidence: result.type_confidence,
                    isConfident: result.type_confidence >= 0.35,
                    isHighConfidence: result.type_confidence >= 0.50,
                    probabilities: result.probabilities || {},
                    inferenceTime: 0,
                    timestamp: new Date(),
                    features: result.features
                } : null,

                // Metadata
                modelUsed: result.model_used,
                apiVersion: '1.0.0'
            };

        } catch (error) {
            console.error('[APIClient] Classification failed:', error);

            // Mark API as unavailable if network error
            if (error.message.includes('Failed to fetch') || error.message.includes('NetworkError')) {
                this.apiAvailable = false;
            }

            return null;
        }
    }

    /**
     * Classify an audio file (File or Blob)
     */
    async classifyFile(file) {
        // Check API availability
        if (this.apiAvailable === null) {
            await this.checkHealth();
        }

        if (!this.apiAvailable) {
            return null;
        }

        try {
            const formData = new FormData();
            formData.append('audio', file);

            const response = await fetch(`${this.apiUrl}/classify`, {
                method: 'POST',
                body: formData,
            });

            if (!response.ok) {
                throw new Error(`API error: ${response.status}`);
            }

            const result = await response.json();

            return {
                detection: {
                    isCry: result.is_cry,
                    confidence: result.cry_confidence,
                    isHighConfidence: result.cry_confidence >= 0.7,
                    scores: {},
                    inferenceTime: 0,
                    timestamp: new Date()
                },
                classification: result.is_cry ? {
                    cryType: result.cry_type || 'general',
                    confidence: result.type_confidence,
                    isConfident: result.type_confidence >= 0.35,
                    probabilities: result.probabilities || {},
                    inferenceTime: 0,
                    timestamp: new Date()
                } : null,
                modelUsed: result.model_used
            };

        } catch (error) {
            console.error('[APIClient] File classification failed:', error);
            return null;
        }
    }

    /**
     * Set API URL (for configuration)
     */
    setApiUrl(url) {
        this.apiUrl = url;
        this.apiAvailable = null; // Reset availability check
        console.log(`[APIClient] API URL changed to: ${url}`);
    }
}

// Export
window.CryClassifierAPIClient = CryClassifierAPIClient;
