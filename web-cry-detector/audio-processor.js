/**
 * AudioProcessor - Web Audio API handler for baby cry detection
 *
 * Captures audio from microphone and provides:
 * - Real-time waveform visualization
 * - Audio level metering
 * - Audio feature extraction for classification
 */

class AudioProcessor {
    constructor() {
        this.audioContext = null;
        this.analyser = null;
        this.microphone = null;
        this.processor = null;
        this.isRecording = false;

        // Audio parameters matching DeepInfant V2
        this.targetSampleRate = 16000; // 16kHz required by model
        this.bufferSize = 2048;
        this.fftSize = 2048;

        // Audio buffer for classification (15600 samples = ~975ms at 16kHz)
        this.requiredSamples = 15600;
        this.audioBuffer = [];

        // Visualization
        this.waveformData = new Uint8Array(this.fftSize);
        this.frequencyData = new Uint8Array(this.fftSize / 2);

        // Callbacks
        this.onAudioLevel = null;
        this.onWaveformData = null;
        this.onAudioReady = null;
        this.onError = null;

        // Feature extraction
        this.mfccExtractor = null;
    }

    /**
     * Initialize audio context and check permissions
     */
    async initialize() {
        try {
            // Request microphone permission
            const stream = await navigator.mediaDevices.getUserMedia({
                audio: {
                    echoCancellation: true,
                    noiseSuppression: true,
                    autoGainControl: true,
                    sampleRate: this.targetSampleRate
                }
            });

            // Create audio context
            this.audioContext = new (window.AudioContext || window.webkitAudioContext)({
                sampleRate: this.targetSampleRate
            });

            // Create analyser for visualization
            this.analyser = this.audioContext.createAnalyser();
            this.analyser.fftSize = this.fftSize;
            this.analyser.smoothingTimeConstant = 0.8;

            // Connect microphone
            this.microphone = this.audioContext.createMediaStreamSource(stream);
            this.microphone.connect(this.analyser);

            // Create script processor for raw audio data
            this.processor = this.audioContext.createScriptProcessor(this.bufferSize, 1, 1);
            this.processor.onaudioprocess = (e) => this.processAudio(e);
            this.analyser.connect(this.processor);
            this.processor.connect(this.audioContext.destination);

            // Update debug info
            if (window.updateDebugInfo) {
                window.updateDebugInfo({
                    sampleRate: this.audioContext.sampleRate,
                    bufferSize: this.bufferSize
                });
            }

            console.log(`[AudioProcessor] Initialized at ${this.audioContext.sampleRate}Hz`);
            return true;

        } catch (error) {
            console.error('[AudioProcessor] Initialization failed:', error);
            if (this.onError) {
                this.onError(error);
            }
            return false;
        }
    }

    /**
     * Start recording and processing audio
     */
    start() {
        if (!this.audioContext) {
            console.error('[AudioProcessor] Not initialized');
            return false;
        }

        // Resume audio context if suspended
        if (this.audioContext.state === 'suspended') {
            this.audioContext.resume();
        }

        this.isRecording = true;
        this.audioBuffer = [];
        this.startVisualization();

        console.log('[AudioProcessor] Started recording');
        return true;
    }

    /**
     * Stop recording
     */
    stop() {
        this.isRecording = false;
        this.stopVisualization();
        this.audioBuffer = [];

        console.log('[AudioProcessor] Stopped recording');
    }

    /**
     * Process incoming audio data
     */
    processAudio(event) {
        if (!this.isRecording) return;

        const inputData = event.inputBuffer.getChannelData(0);

        // Add samples to buffer
        for (let i = 0; i < inputData.length; i++) {
            this.audioBuffer.push(inputData[i]);
        }

        // Check if we have enough samples for classification
        if (this.audioBuffer.length >= this.requiredSamples) {
            const samples = this.audioBuffer.slice(0, this.requiredSamples);
            this.audioBuffer = this.audioBuffer.slice(this.requiredSamples / 2); // 50% overlap

            if (this.onAudioReady) {
                this.onAudioReady(new Float32Array(samples));
            }
        }
    }

    /**
     * Start visualization loop
     */
    startVisualization() {
        const visualize = () => {
            if (!this.isRecording) return;

            // Get waveform data
            this.analyser.getByteTimeDomainData(this.waveformData);

            // Get frequency data
            this.analyser.getByteFrequencyData(this.frequencyData);

            // Calculate audio level (RMS)
            let sum = 0;
            for (let i = 0; i < this.waveformData.length; i++) {
                const normalized = (this.waveformData[i] - 128) / 128;
                sum += normalized * normalized;
            }
            const rms = Math.sqrt(sum / this.waveformData.length);
            const db = 20 * Math.log10(Math.max(rms, 0.00001));
            const normalizedLevel = Math.max(0, Math.min(1, (db + 60) / 60));

            // Trigger callbacks
            if (this.onAudioLevel) {
                this.onAudioLevel(normalizedLevel, db);
            }

            if (this.onWaveformData) {
                this.onWaveformData(this.waveformData, this.frequencyData);
            }

            requestAnimationFrame(visualize);
        };

        visualize();
    }

    /**
     * Stop visualization loop
     */
    stopVisualization() {
        // Visualization stops when isRecording is false
    }

    /**
     * Extract audio features for classification
     * Returns features similar to what DeepInfant V2 expects
     */
    extractFeatures(samples) {
        const features = {
            // Basic statistics
            mean: 0,
            std: 0,
            max: 0,
            min: Infinity,
            zeroCrossings: 0,

            // Spectral features
            spectralCentroid: 0,
            spectralRolloff: 0,
            spectralFlux: 0,

            // Energy features
            rms: 0,
            energy: 0,

            // Pitch-related
            dominantFrequency: 0,
            harmonicity: 0,

            // Temporal features
            attackTime: 0,
            sustainRatio: 0
        };

        // Calculate basic statistics
        let sum = 0;
        let sumSquares = 0;
        let prevSample = 0;

        for (let i = 0; i < samples.length; i++) {
            const sample = samples[i];
            sum += sample;
            sumSquares += sample * sample;

            if (sample > features.max) features.max = sample;
            if (sample < features.min) features.min = sample;

            // Zero crossings
            if (i > 0 && ((sample >= 0 && prevSample < 0) || (sample < 0 && prevSample >= 0))) {
                features.zeroCrossings++;
            }
            prevSample = sample;
        }

        features.mean = sum / samples.length;
        features.energy = sumSquares;
        features.rms = Math.sqrt(sumSquares / samples.length);

        // Standard deviation
        let varianceSum = 0;
        for (let i = 0; i < samples.length; i++) {
            const diff = samples[i] - features.mean;
            varianceSum += diff * diff;
        }
        features.std = Math.sqrt(varianceSum / samples.length);

        // FFT for spectral features
        const fftResult = this.computeFFT(samples);

        // Spectral centroid (center of mass of spectrum)
        let weightedSum = 0;
        let magnitudeSum = 0;
        for (let i = 0; i < fftResult.length; i++) {
            const freq = (i * this.targetSampleRate) / (2 * fftResult.length);
            weightedSum += freq * fftResult[i];
            magnitudeSum += fftResult[i];
        }
        features.spectralCentroid = magnitudeSum > 0 ? weightedSum / magnitudeSum : 0;

        // Spectral rolloff (frequency below which 85% of energy is concentrated)
        const totalEnergy = fftResult.reduce((a, b) => a + b, 0);
        let cumulativeEnergy = 0;
        for (let i = 0; i < fftResult.length; i++) {
            cumulativeEnergy += fftResult[i];
            if (cumulativeEnergy >= totalEnergy * 0.85) {
                features.spectralRolloff = (i * this.targetSampleRate) / (2 * fftResult.length);
                break;
            }
        }

        // Dominant frequency (peak in spectrum)
        let maxMagnitude = 0;
        let maxIndex = 0;
        for (let i = 1; i < fftResult.length; i++) {
            if (fftResult[i] > maxMagnitude) {
                maxMagnitude = fftResult[i];
                maxIndex = i;
            }
        }
        features.dominantFrequency = (maxIndex * this.targetSampleRate) / (2 * fftResult.length);

        // Attack time (time to reach peak amplitude)
        const peakIndex = samples.indexOf(features.max);
        features.attackTime = peakIndex / this.targetSampleRate;

        // Harmonicity (ratio of harmonic energy to total energy)
        // Simplified: ratio of energy at fundamental and harmonics
        features.harmonicity = this.calculateHarmonicity(fftResult, maxIndex);

        return features;
    }

    /**
     * Compute simple FFT magnitude spectrum
     */
    computeFFT(samples) {
        const n = samples.length;
        const halfN = Math.floor(n / 2);
        const magnitude = new Float32Array(halfN);

        // Simple DFT (for demonstration - in production use Web Audio AnalyserNode or library)
        // This is computationally expensive for large buffers
        const chunkSize = 1024;
        const numChunks = Math.floor(n / chunkSize);

        for (let c = 0; c < numChunks; c++) {
            const offset = c * chunkSize;
            for (let k = 0; k < Math.min(halfN, chunkSize / 2); k++) {
                let real = 0;
                let imag = 0;
                for (let t = 0; t < chunkSize; t++) {
                    const angle = (2 * Math.PI * k * t) / chunkSize;
                    real += samples[offset + t] * Math.cos(angle);
                    imag -= samples[offset + t] * Math.sin(angle);
                }
                magnitude[k] += Math.sqrt(real * real + imag * imag) / numChunks;
            }
        }

        return magnitude;
    }

    /**
     * Calculate harmonicity from FFT result
     */
    calculateHarmonicity(fftResult, fundamentalIndex) {
        if (fundamentalIndex < 1) return 0;

        let harmonicEnergy = fftResult[fundamentalIndex] || 0;
        let totalEnergy = fftResult.reduce((a, b) => a + b, 0);

        // Add energy at harmonics (2x, 3x, 4x fundamental)
        for (let h = 2; h <= 4; h++) {
            const harmonicIndex = fundamentalIndex * h;
            if (harmonicIndex < fftResult.length) {
                // Allow some tolerance in harmonic frequency
                for (let offset = -2; offset <= 2; offset++) {
                    const idx = harmonicIndex + offset;
                    if (idx >= 0 && idx < fftResult.length) {
                        harmonicEnergy += fftResult[idx] * 0.5;
                    }
                }
            }
        }

        return totalEnergy > 0 ? harmonicEnergy / totalEnergy : 0;
    }

    /**
     * Load audio file for analysis
     */
    async loadAudioFile(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();

            reader.onload = async (e) => {
                try {
                    if (!this.audioContext) {
                        this.audioContext = new (window.AudioContext || window.webkitAudioContext)({
                            sampleRate: this.targetSampleRate
                        });
                    }

                    const audioBuffer = await this.audioContext.decodeAudioData(e.target.result);
                    const channelData = audioBuffer.getChannelData(0);

                    // Resample if needed
                    const resampledData = this.resample(
                        channelData,
                        audioBuffer.sampleRate,
                        this.targetSampleRate
                    );

                    // Take first requiredSamples or pad with zeros
                    const samples = new Float32Array(this.requiredSamples);
                    for (let i = 0; i < this.requiredSamples; i++) {
                        samples[i] = i < resampledData.length ? resampledData[i] : 0;
                    }

                    resolve(samples);

                } catch (error) {
                    reject(error);
                }
            };

            reader.onerror = reject;
            reader.readAsArrayBuffer(file);
        });
    }

    /**
     * Simple linear resampling
     */
    resample(data, fromSampleRate, toSampleRate) {
        if (fromSampleRate === toSampleRate) {
            return data;
        }

        const ratio = fromSampleRate / toSampleRate;
        const newLength = Math.floor(data.length / ratio);
        const result = new Float32Array(newLength);

        for (let i = 0; i < newLength; i++) {
            const srcIndex = i * ratio;
            const srcIndexFloor = Math.floor(srcIndex);
            const srcIndexCeil = Math.min(srcIndexFloor + 1, data.length - 1);
            const fraction = srcIndex - srcIndexFloor;

            // Linear interpolation
            result[i] = data[srcIndexFloor] * (1 - fraction) + data[srcIndexCeil] * fraction;
        }

        return result;
    }

    /**
     * Clean up resources
     */
    dispose() {
        this.stop();

        if (this.microphone) {
            this.microphone.disconnect();
        }

        if (this.processor) {
            this.processor.disconnect();
        }

        if (this.analyser) {
            this.analyser.disconnect();
        }

        if (this.audioContext) {
            this.audioContext.close();
        }

        console.log('[AudioProcessor] Disposed');
    }
}

// Export for use in other modules
window.AudioProcessor = AudioProcessor;
