/**
 * Baby Cry Detector - Main Application
 *
 * Two-Stage Detection Pipeline:
 * Stage 1: Binary cry detection - Is this a baby cry?
 * Stage 2: Cry type classification - What type of cry? (only if Stage 1 = Yes)
 */

class CryDetectorApp {
    constructor() {
        this.audioProcessor = null;
        this.cryDetector = null;    // Stage 1: Binary detection (fallback)
        this.classifier = null;      // Stage 2: Type classification (fallback)
        this.apiClient = null;       // API client for backend classification
        this.useAPI = true;          // Try to use API first
        this.isRunning = false;
        this.history = [];
        this.maxHistoryItems = 20;
        this.categoryMode = 'simple'; // 'simple' (3) or 'detailed' (6)

        // DOM elements
        this.elements = {
            // Status
            statusIndicator: document.getElementById('statusIndicator'),
            statusText: document.getElementById('statusText'),
            modelStatus: document.getElementById('modelStatus'),

            // Visualization
            waveformCanvas: document.getElementById('waveformCanvas'),
            levelFill: document.getElementById('levelFill'),
            levelValue: document.getElementById('levelValue'),

            // Controls
            startBtn: document.getElementById('startBtn'),
            stopBtn: document.getElementById('stopBtn'),
            uploadBtn: document.getElementById('uploadBtn'),
            audioFileInput: document.getElementById('audioFileInput'),

            // Stage 1: Cry Detection
            detectionIndicator: document.getElementById('detectionIndicator'),
            detectionIcon: document.getElementById('detectionIcon'),
            detectionLabel: document.getElementById('detectionLabel'),
            detectionConfidence: document.getElementById('detectionConfidence'),
            scoreF0: document.getElementById('scoreF0'),
            scoreF0Val: document.getElementById('scoreF0Val'),
            scoreHarmonic: document.getElementById('scoreHarmonic'),
            scoreHarmonicVal: document.getElementById('scoreHarmonicVal'),
            scoreFormants: document.getElementById('scoreFormants'),
            scoreFormantsVal: document.getElementById('scoreFormantsVal'),
            scoreTemporal: document.getElementById('scoreTemporal'),
            scoreTemporalVal: document.getElementById('scoreTemporalVal'),
            scoreAntiMusic: document.getElementById('scoreAntiMusic'),
            scoreAntiMusicVal: document.getElementById('scoreAntiMusicVal'),

            // Stage 2: Type Classification
            stage2Section: document.getElementById('stage2Section'),
            cryTypeIcon: document.getElementById('cryTypeIcon'),
            cryTypeLabel: document.getElementById('cryTypeLabel'),
            confidenceValue: document.getElementById('confidenceValue'),

            // Simple mode (3 categories)
            simpleProbabilities: document.getElementById('simpleProbabilities'),
            probUrgent: document.getElementById('probUrgent'),
            probUrgentVal: document.getElementById('probUrgentVal'),
            probNeeds: document.getElementById('probNeeds'),
            probNeedsVal: document.getElementById('probNeedsVal'),
            probComfort: document.getElementById('probComfort'),
            probComfortVal: document.getElementById('probComfortVal'),

            // Detailed mode (6 categories)
            detailedProbabilities: document.getElementById('detailedProbabilities'),
            probHunger: document.getElementById('probHunger'),
            probTired: document.getElementById('probTired'),
            probPain: document.getElementById('probPain'),
            probAttention: document.getElementById('probAttention'),
            probDiscomfort: document.getElementById('probDiscomfort'),
            probGeneral: document.getElementById('probGeneral'),
            probHungerVal: document.getElementById('probHungerVal'),
            probTiredVal: document.getElementById('probTiredVal'),
            probPainVal: document.getElementById('probPainVal'),
            probAttentionVal: document.getElementById('probAttentionVal'),
            probDiscomfortVal: document.getElementById('probDiscomfortVal'),
            probGeneralVal: document.getElementById('probGeneralVal'),

            // History
            historyList: document.getElementById('historyList'),
            clearHistoryBtn: document.getElementById('clearHistoryBtn'),

            // Debug
            debugSampleRate: document.getElementById('debugSampleRate'),
            debugBufferSize: document.getElementById('debugBufferSize'),
            debugDetectionTime: document.getElementById('debugDetectionTime'),
            debugInferenceTime: document.getElementById('debugInferenceTime'),
            debugFeatures: document.getElementById('debugFeatures')
        };

        // Canvas context for waveform
        this.canvasCtx = this.elements.waveformCanvas.getContext('2d');

        this.init();
    }

    async init() {
        console.log('[CryDetectorApp] Initializing two-stage pipeline...');

        // Create instances
        this.audioProcessor = new AudioProcessor();
        this.cryDetector = new CryDetector();      // Stage 1 (fallback)
        this.classifier = new CryClassifier();      // Stage 2 (fallback)

        // Initialize API client for backend classification
        const apiUrl = this.getApiUrl();
        this.apiClient = new CryClassifierAPIClient({
            apiUrl: apiUrl,
            onStatusChange: (status) => this.handleApiStatusChange(status)
        });

        // Set up callbacks
        this.audioProcessor.onAudioLevel = (level, db) => this.updateAudioLevel(level, db);
        this.audioProcessor.onWaveformData = (waveform, frequency) => this.drawWaveform(waveform, frequency);
        this.audioProcessor.onAudioReady = (samples) => this.processAudio(samples);
        this.audioProcessor.onError = (error) => this.handleError(error);

        // Set up event listeners
        this.setupEventListeners();

        // Initialize audio processor
        this.updateStatus('Initializing...', 'loading');

        // Check API availability
        const apiHealth = await this.apiClient.checkHealth();
        if (apiHealth) {
            console.log('[CryDetectorApp] Backend API available:', apiHealth.model_type);
            this.useAPI = true;
        } else {
            console.log('[CryDetectorApp] Backend API unavailable, using client-side fallback');
            this.useAPI = false;
        }

        const initialized = await this.audioProcessor.initialize();

        if (initialized) {
            this.updateStatus('Ready', 'ready');
            const modelInfo = this.useAPI
                ? `API: ${apiHealth?.model_type || 'Connected'}`
                : 'Client-side (rule-based)';
            this.elements.modelStatus.textContent = modelInfo;
            this.elements.modelStatus.classList.add('ready');
            this.elements.startBtn.disabled = false;
        } else {
            this.updateStatus('Error', 'error');
            this.elements.modelStatus.textContent = 'Failed to initialize audio';
        }

        // Make debug info updater available globally
        window.updateDebugInfo = (info) => this.updateDebugInfo(info);

        console.log('[CryDetectorApp] Initialization complete');
    }

    getApiUrl() {
        // Check for URL parameter first
        const params = new URLSearchParams(window.location.search);
        if (params.has('api')) {
            return params.get('api');
        }
        // Default to local development server
        return 'http://localhost:8000';
    }

    handleApiStatusChange(status) {
        console.log('[CryDetectorApp] API status changed:', status);
        this.useAPI = status.available;
        if (status.available) {
            this.elements.modelStatus.textContent = `API: ${status.modelType || 'Connected'}`;
        } else {
            this.elements.modelStatus.textContent = 'Client-side (rule-based)';
        }
    }

    setupEventListeners() {
        // Start button
        this.elements.startBtn.addEventListener('click', () => this.start());

        // Stop button
        this.elements.stopBtn.addEventListener('click', () => this.stop());

        // Upload button
        this.elements.uploadBtn.addEventListener('click', () => {
            this.elements.audioFileInput.click();
        });

        // File input
        this.elements.audioFileInput.addEventListener('change', (e) => {
            if (e.target.files.length > 0) {
                this.processAudioFile(e.target.files[0]);
            }
        });

        // Clear history
        this.elements.clearHistoryBtn.addEventListener('click', () => this.clearHistory());

        // Category mode toggle
        document.querySelectorAll('input[name="categoryMode"]').forEach(radio => {
            radio.addEventListener('change', (e) => {
                this.setCategoryMode(e.target.value);
            });
        });

        // Handle page visibility changes
        document.addEventListener('visibilitychange', () => {
            if (document.hidden && this.isRunning) {
                console.log('[CryDetectorApp] Tab hidden, pausing...');
            }
        });
    }

    setCategoryMode(mode) {
        this.categoryMode = mode;

        if (mode === 'simple') {
            this.elements.simpleProbabilities.style.display = 'block';
            this.elements.detailedProbabilities.style.display = 'none';
        } else {
            this.elements.simpleProbabilities.style.display = 'none';
            this.elements.detailedProbabilities.style.display = 'block';
        }

        console.log(`[CryDetectorApp] Category mode: ${mode}`);
    }

    start() {
        if (this.isRunning) return;

        const success = this.audioProcessor.start();
        if (success) {
            this.isRunning = true;
            this.updateStatus('Listening', 'listening');
            this.elements.startBtn.disabled = true;
            this.elements.stopBtn.disabled = false;

            // Reset detection display
            this.resetDetectionDisplay();

            console.log('[CryDetectorApp] Started');
        }
    }

    stop() {
        if (!this.isRunning) return;

        this.audioProcessor.stop();
        this.isRunning = false;
        this.updateStatus('Ready', 'ready');
        this.elements.startBtn.disabled = false;
        this.elements.stopBtn.disabled = true;

        // Clear waveform
        this.clearWaveform();

        console.log('[CryDetectorApp] Stopped');
    }

    async processAudioFile(file) {
        console.log('[CryDetectorApp] Processing file:', file.name, file.type, file.size, 'bytes');
        this.updateStatus('Processing file...', 'loading');

        try {
            // Ensure audio context exists (might not if microphone permission was denied)
            if (!this.audioProcessor.audioContext) {
                console.log('[CryDetectorApp] Creating audio context for file processing...');
                this.audioProcessor.audioContext = new (window.AudioContext || window.webkitAudioContext)({
                    sampleRate: 16000
                });
            }

            // Resume audio context if suspended (browser autoplay policy)
            if (this.audioProcessor.audioContext.state === 'suspended') {
                console.log('[CryDetectorApp] Resuming suspended audio context...');
                await this.audioProcessor.audioContext.resume();
            }

            const samples = await this.audioProcessor.loadAudioFile(file);
            console.log('[CryDetectorApp] Loaded', samples.length, 'samples from file');

            // Process with API directly for file uploads (bypass quiet audio check)
            await this.processAudioFromFile(samples);
            this.updateStatus('Ready', 'ready');
        } catch (error) {
            console.error('[CryDetectorApp] Error processing file:', error);
            this.handleError(error);
            this.updateStatus('Error', 'error');
            this.elements.modelStatus.textContent = `File error: ${error.message}`;
        }
    }

    async processAudioFromFile(samples) {
        console.log('[CryDetectorApp] Processing audio from file...');

        // Extract features for display
        const features = this.audioProcessor.extractFeatures(samples);
        console.log('[CryDetectorApp] Extracted features:', features);

        // Try API classification first
        if (this.useAPI && this.apiClient) {
            console.log('[CryDetectorApp] Sending to API for classification...');
            const apiResult = await this.apiClient.classify(samples, 16000);

            if (apiResult) {
                console.log('[CryDetectorApp] API result:', apiResult);

                // Display detection result
                this.displayDetectionResult(apiResult.detection);

                this.updateDebugInfo({
                    detectionTime: 'API',
                    features: JSON.stringify(apiResult.classification?.features || this.normalizeFeatures(features), null, 2)
                });

                if (apiResult.detection.isCry && apiResult.classification) {
                    this.displayClassificationResult(apiResult.classification);
                    this.updateDebugInfo({ inferenceTime: 'API (' + apiResult.modelUsed + ')' });
                    this.addToHistory({
                        detection: apiResult.detection,
                        classification: apiResult.classification
                    });
                } else {
                    this.elements.stage2Section.style.display = 'none';
                }
                return;
            } else {
                console.log('[CryDetectorApp] API returned null, falling back to local...');
            }
        }

        // Fallback to local classification
        console.log('[CryDetectorApp] Using local classification...');
        const detectionResult = this.cryDetector.detect(features, samples);
        this.displayDetectionResult(detectionResult);

        this.updateDebugInfo({
            detectionTime: detectionResult.inferenceTime.toFixed(2) + 'ms (local)',
            features: JSON.stringify(this.normalizeFeatures(features), null, 2)
        });

        if (detectionResult.isCry) {
            const classificationResult = this.classifier.classify(features);
            this.displayClassificationResult(classificationResult);
            this.updateDebugInfo({
                inferenceTime: classificationResult.inferenceTime.toFixed(2) + 'ms (local)'
            });
            this.addToHistory({
                detection: detectionResult,
                classification: classificationResult
            });
        } else {
            this.elements.stage2Section.style.display = 'none';
        }
    }

    async processAudio(samples) {
        // Extract features for fallback and display
        const features = this.audioProcessor.extractFeatures(samples);

        // Check if audio level is sufficient
        const rmsDb = 20 * Math.log10(Math.max(features.rms, 0.00001));
        if (rmsDb < -40) {
            // Audio too quiet, skip classification
            return;
        }

        // Update status to detecting
        if (this.isRunning) {
            this.updateStatus('Detecting...', 'detecting');
        }

        // Try API classification first if available
        if (this.useAPI && this.apiClient) {
            const apiResult = await this.apiClient.classify(samples, 16000);

            if (apiResult) {
                // API returned result - use it
                this.displayDetectionResult(apiResult.detection);

                this.updateDebugInfo({
                    detectionTime: 'API',
                    features: JSON.stringify(apiResult.classification?.features || this.normalizeFeatures(features), null, 2)
                });

                if (apiResult.detection.isCry && apiResult.classification) {
                    this.displayClassificationResult(apiResult.classification);
                    this.updateDebugInfo({ inferenceTime: 'API (' + apiResult.modelUsed + ')' });
                    this.addToHistory({
                        detection: apiResult.detection,
                        classification: apiResult.classification
                    });
                } else {
                    this.elements.stage2Section.style.display = 'none';
                }

                // Return to listening
                if (this.isRunning) {
                    setTimeout(() => {
                        if (this.isRunning) {
                            this.updateStatus('Listening', 'listening');
                        }
                    }, 500);
                }
                return;
            }
        }

        // Fallback to client-side classification
        // ===== STAGE 1: Binary Cry Detection =====
        const detectionResult = this.cryDetector.detect(features, samples);
        this.displayDetectionResult(detectionResult);

        // Update debug info
        this.updateDebugInfo({
            detectionTime: detectionResult.inferenceTime.toFixed(2) + 'ms (local)',
            features: JSON.stringify(this.normalizeFeatures(features), null, 2)
        });

        // ===== STAGE 2: Cry Type Classification (only if cry detected) =====
        if (detectionResult.isCry) {
            const classificationResult = this.classifier.classify(features);
            this.displayClassificationResult(classificationResult);

            // Update debug info
            this.updateDebugInfo({
                inferenceTime: classificationResult.inferenceTime.toFixed(2) + 'ms (local)'
            });

            // Add to history
            this.addToHistory({
                detection: detectionResult,
                classification: classificationResult
            });
        } else {
            // Hide stage 2 when no cry detected
            this.elements.stage2Section.style.display = 'none';
        }

        // Return to listening state
        if (this.isRunning) {
            setTimeout(() => {
                if (this.isRunning) {
                    this.updateStatus('Listening', 'listening');
                }
            }, 500);
        }
    }

    displayDetectionResult(result) {
        const { isCry, confidence, scores } = result;

        // Update main detection indicator
        if (isCry) {
            this.elements.detectionIcon.textContent = '✅';
            this.elements.detectionLabel.textContent = 'Baby Cry Detected';
            this.elements.detectionIndicator.classList.remove('not-cry');
            this.elements.detectionIndicator.classList.add('is-cry');

            // Show stage 2
            this.elements.stage2Section.style.display = 'block';
        } else {
            this.elements.detectionIcon.textContent = '❌';
            this.elements.detectionLabel.textContent = 'Not a Baby Cry';
            this.elements.detectionIndicator.classList.remove('is-cry');
            this.elements.detectionIndicator.classList.add('not-cry');

            // Hide stage 2
            this.elements.stage2Section.style.display = 'none';
        }

        // Update confidence
        const confidencePercent = (confidence * 100).toFixed(1);
        this.elements.detectionConfidence.textContent = `Confidence: ${confidencePercent}%`;

        // Update individual score bars
        this.updateScoreBar('F0', scores.f0InRange);
        this.updateScoreBar('Harmonic', scores.harmonicEnergy);
        this.updateScoreBar('Formants', scores.cryFormants);
        this.updateScoreBar('Temporal', scores.temporalVariation);
        this.updateScoreBar('AntiMusic', scores.antiMusicScore);
    }

    updateScoreBar(name, score) {
        const percentage = (score * 100).toFixed(1);
        const fillEl = this.elements[`score${name}`];
        const valEl = this.elements[`score${name}Val`];

        if (fillEl && valEl) {
            fillEl.style.width = `${percentage}%`;
            valEl.textContent = `${percentage}%`;

            // Color based on score
            if (score >= 0.7) {
                fillEl.style.backgroundColor = '#10b981'; // Green
            } else if (score >= 0.4) {
                fillEl.style.backgroundColor = '#f59e0b'; // Yellow
            } else {
                fillEl.style.backgroundColor = '#ef4444'; // Red
            }
        }
    }

    displayClassificationResult(result) {
        const { cryType, confidence, probabilities, isConfident } = result;

        // Update main result display
        const icon = this.classifier.getIcon(cryType);

        this.elements.cryTypeIcon.textContent = icon;
        this.elements.cryTypeLabel.textContent = isConfident
            ? this.formatCryType(cryType)
            : 'Analyzing...';

        this.elements.confidenceValue.textContent = `${(confidence * 100).toFixed(1)}% confidence`;

        // Update probability bars based on mode
        if (this.categoryMode === 'simple') {
            this.updateSimpleProbabilities(probabilities);
        } else {
            this.updateDetailedProbabilities(probabilities);
        }
    }

    updateSimpleProbabilities(probabilities) {
        // Aggregate into 3 categories:
        // Urgent = Pain + Discomfort
        // Needs = Hunger + Tired
        // Comfort = Attention + General

        const urgent = (probabilities.pain || 0) + (probabilities.discomfort || 0);
        const needs = (probabilities.hunger || 0) + (probabilities.tired || 0);
        const comfort = (probabilities.attention || 0) + (probabilities.general || 0);

        // Normalize
        const total = urgent + needs + comfort;
        const urgentNorm = total > 0 ? urgent / total : 0.33;
        const needsNorm = total > 0 ? needs / total : 0.33;
        const comfortNorm = total > 0 ? comfort / total : 0.33;

        // Update UI
        this.elements.probUrgent.style.width = `${urgentNorm * 100}%`;
        this.elements.probUrgentVal.textContent = `${(urgentNorm * 100).toFixed(1)}%`;

        this.elements.probNeeds.style.width = `${needsNorm * 100}%`;
        this.elements.probNeedsVal.textContent = `${(needsNorm * 100).toFixed(1)}%`;

        this.elements.probComfort.style.width = `${comfortNorm * 100}%`;
        this.elements.probComfortVal.textContent = `${(comfortNorm * 100).toFixed(1)}%`;
    }

    updateDetailedProbabilities(probabilities) {
        const types = ['hunger', 'tired', 'pain', 'attention', 'discomfort', 'general'];

        for (const type of types) {
            const prob = probabilities[type] || 0;
            const percentage = (prob * 100).toFixed(1);

            const fillEl = this.elements[`prob${this.capitalize(type)}`];
            const valEl = this.elements[`prob${this.capitalize(type)}Val`];

            if (fillEl && valEl) {
                fillEl.style.width = `${percentage}%`;
                valEl.textContent = `${percentage}%`;
            }
        }
    }

    resetDetectionDisplay() {
        this.elements.detectionIcon.textContent = '❓';
        this.elements.detectionLabel.textContent = 'Waiting for audio...';
        this.elements.detectionConfidence.textContent = '--';
        this.elements.detectionIndicator.classList.remove('is-cry', 'not-cry');

        // Reset score bars
        ['F0', 'Harmonic', 'Formants', 'Temporal', 'AntiMusic'].forEach(name => {
            const fillEl = this.elements[`score${name}`];
            const valEl = this.elements[`score${name}Val`];
            if (fillEl) fillEl.style.width = '0%';
            if (valEl) valEl.textContent = '0%';
        });

        // Hide stage 2
        this.elements.stage2Section.style.display = 'none';
    }

    addToHistory(result) {
        this.history.unshift(result);

        if (this.history.length > this.maxHistoryItems) {
            this.history.pop();
        }

        this.renderHistory();
    }

    renderHistory() {
        if (this.history.length === 0) {
            this.elements.historyList.innerHTML = '<p class="empty-history">No detections yet</p>';
            return;
        }

        const html = this.history.map((item) => {
            const { detection, classification } = item;
            const icon = this.classifier.getIcon(classification.cryType);
            const time = this.formatTime(detection.timestamp);
            const cryConfidence = (detection.confidence * 100).toFixed(0);
            const typeConfidence = (classification.confidence * 100).toFixed(0);

            return `
                <div class="history-item">
                    <span class="history-icon">${icon}</span>
                    <div class="history-info">
                        <span class="history-type">${this.formatCryType(classification.cryType)}</span>
                        <span class="history-time">${time}</span>
                    </div>
                    <div class="history-confidence">
                        <span class="cry-conf">Cry: ${cryConfidence}%</span>
                        <span class="type-conf">Type: ${typeConfidence}%</span>
                    </div>
                </div>
            `;
        }).join('');

        this.elements.historyList.innerHTML = html;
    }

    clearHistory() {
        this.history = [];
        this.renderHistory();
    }

    updateStatus(text, state) {
        this.elements.statusText.textContent = text;
        this.elements.statusIndicator.className = 'status-indicator';

        if (state === 'listening') {
            this.elements.statusIndicator.classList.add('listening');
        } else if (state === 'detecting') {
            this.elements.statusIndicator.classList.add('detecting');
        } else if (state === 'error') {
            this.elements.statusIndicator.classList.add('error');
        }
    }

    updateAudioLevel(level, db) {
        this.elements.levelFill.style.width = `${level * 100}%`;
        this.elements.levelValue.textContent = `${db.toFixed(1)} dB`;
    }

    drawWaveform(waveformData, frequencyData) {
        const canvas = this.elements.waveformCanvas;
        const ctx = this.canvasCtx;
        const width = canvas.width;
        const height = canvas.height;

        // Clear canvas
        ctx.fillStyle = 'rgba(15, 23, 42, 0.3)';
        ctx.fillRect(0, 0, width, height);

        // Draw frequency bars
        const barWidth = width / frequencyData.length * 2;
        const barSpacing = 1;

        ctx.fillStyle = 'rgba(99, 102, 241, 0.3)';
        for (let i = 0; i < frequencyData.length / 2; i++) {
            const barHeight = (frequencyData[i] / 255) * height * 0.8;
            const x = i * (barWidth + barSpacing);
            const y = height - barHeight;

            ctx.fillRect(x, y, barWidth, barHeight);
        }

        // Draw waveform
        ctx.beginPath();
        ctx.strokeStyle = '#6366f1';
        ctx.lineWidth = 2;

        const sliceWidth = width / waveformData.length;
        let x = 0;

        for (let i = 0; i < waveformData.length; i++) {
            const v = waveformData[i] / 128.0;
            const y = (v * height) / 2;

            if (i === 0) {
                ctx.moveTo(x, y);
            } else {
                ctx.lineTo(x, y);
            }

            x += sliceWidth;
        }

        ctx.stroke();

        // Draw center line
        ctx.beginPath();
        ctx.strokeStyle = 'rgba(255, 255, 255, 0.1)';
        ctx.lineWidth = 1;
        ctx.moveTo(0, height / 2);
        ctx.lineTo(width, height / 2);
        ctx.stroke();
    }

    clearWaveform() {
        const canvas = this.elements.waveformCanvas;
        const ctx = this.canvasCtx;

        ctx.fillStyle = 'rgba(15, 23, 42, 0.5)';
        ctx.fillRect(0, 0, canvas.width, canvas.height);

        this.elements.levelFill.style.width = '0%';
        this.elements.levelValue.textContent = '0 dB';
    }

    updateDebugInfo(info) {
        if (info.sampleRate !== undefined) {
            this.elements.debugSampleRate.textContent = info.sampleRate + ' Hz';
        }
        if (info.bufferSize !== undefined) {
            this.elements.debugBufferSize.textContent = info.bufferSize;
        }
        if (info.detectionTime !== undefined) {
            this.elements.debugDetectionTime.textContent = info.detectionTime;
        }
        if (info.inferenceTime !== undefined) {
            this.elements.debugInferenceTime.textContent = info.inferenceTime;
        }
        if (info.features !== undefined) {
            this.elements.debugFeatures.textContent = info.features;
        }
    }

    normalizeFeatures(features) {
        return {
            dominantFrequency: Math.round(features.dominantFrequency || 0) + ' Hz',
            spectralCentroid: Math.round(features.spectralCentroid || 0) + ' Hz',
            spectralRolloff: Math.round(features.spectralRolloff || 0) + ' Hz',
            rms: (features.rms || 0).toFixed(4),
            zeroCrossings: Math.round(features.zeroCrossings || 0),
            harmonicity: (features.harmonicity || 0).toFixed(3),
            attackTime: ((features.attackTime || 0) * 1000).toFixed(1) + 'ms'
        };
    }

    handleError(error) {
        console.error('[CryDetectorApp] Error:', error);

        this.updateStatus('Error', 'error');

        if (error.name === 'NotAllowedError') {
            this.elements.modelStatus.textContent = 'Microphone permission denied';
        } else if (error.name === 'NotFoundError') {
            this.elements.modelStatus.textContent = 'No microphone found';
        } else {
            this.elements.modelStatus.textContent = `Error: ${error.message}`;
        }
    }

    formatCryType(type) {
        if (!type || type === 'unknown') return 'Unknown';
        return type.charAt(0).toUpperCase() + type.slice(1);
    }

    capitalize(str) {
        return str.charAt(0).toUpperCase() + str.slice(1);
    }

    formatTime(date) {
        return date.toLocaleTimeString('en-US', {
            hour: '2-digit',
            minute: '2-digit',
            second: '2-digit'
        });
    }

    dispose() {
        this.stop();
        if (this.audioProcessor) {
            this.audioProcessor.dispose();
        }
    }
}

// Initialize app when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
    window.cryDetectorApp = new CryDetectorApp();
});

// Handle page unload
window.addEventListener('beforeunload', () => {
    if (window.cryDetectorApp) {
        window.cryDetectorApp.dispose();
    }
});
