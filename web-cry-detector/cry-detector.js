/**
 * CryDetector - Binary baby cry detection
 *
 * Stage 1 of the two-stage detection pipeline:
 * 1. CryDetector: Is this a baby cry? (Yes/No with confidence)
 * 2. CryClassifier: What type of cry? (Only runs if Stage 1 = Yes)
 *
 * Uses infant-specific audio characteristics:
 * - Fundamental frequency (F0): 250-600 Hz for infants
 * - High-energy harmonics in 1-4 kHz range
 * - Characteristic spectral envelope
 * - Temporal patterns (burst-pause structure)
 */

class CryDetector {
    constructor() {
        // Detection thresholds
        this.cryConfidenceThreshold = 0.60;  // Minimum to consider it a cry
        this.highConfidenceThreshold = 0.80; // High confidence cry

        // Infant vocal characteristics
        this.infantF0Range = { min: 250, max: 600 };     // Fundamental frequency
        this.harmonicRange = { min: 500, max: 4000 };    // Harmonic content
        this.cryEnergyBands = [
            { min: 250, max: 600, weight: 0.25 },   // F0 band
            { min: 1000, max: 2000, weight: 0.30 }, // First harmonic region
            { min: 2000, max: 4000, weight: 0.25 }, // Upper harmonics
            { min: 300, max: 800, weight: 0.20 }    // Cry formant region
        ];

        // Non-cry characteristics (music, speech, noise)
        this.musicCharacteristics = {
            harmonicityThreshold: 0.7,  // Music tends to be very harmonic
            rhythmRegularity: 0.8,      // Music has regular rhythm
            spectralFlatness: 0.3       // Music has distinct peaks
        };

        // Feature weights for cry detection
        this.featureWeights = {
            f0InRange: 0.25,           // F0 in infant range
            harmonicEnergy: 0.20,      // Energy in harmonic bands
            spectralSlope: 0.15,       // Cries have characteristic slope
            temporalVariation: 0.15,   // Cries vary over time
            cryFormants: 0.15,         // Cry-specific formant patterns
            antiMusicScore: 0.10       // Penalty for music-like features
        };

        // Callbacks
        this.onDetection = null;

        console.log('[CryDetector] Initialized - Binary cry detection enabled');
    }

    /**
     * Detect if audio contains baby crying
     * @param {Object} features - Audio features from AudioProcessor
     * @param {Float32Array} samples - Raw audio samples (optional, for advanced analysis)
     * @returns {Object} Detection result with isCry boolean and confidence
     */
    detect(features, samples = null) {
        const startTime = performance.now();

        // Calculate individual feature scores
        const scores = {
            f0InRange: this.scoreF0InRange(features),
            harmonicEnergy: this.scoreHarmonicEnergy(features),
            spectralSlope: this.scoreSpectralSlope(features),
            temporalVariation: this.scoreTemporalVariation(features),
            cryFormants: this.scoreCryFormants(features),
            antiMusicScore: this.scoreAntiMusic(features)
        };

        // Calculate weighted confidence
        let confidence = 0;
        let totalWeight = 0;

        for (const [feature, score] of Object.entries(scores)) {
            const weight = this.featureWeights[feature] || 0;
            confidence += score * weight;
            totalWeight += weight;
        }

        if (totalWeight > 0) {
            confidence = confidence / totalWeight;
        }

        // Apply sigmoid for smoother probability
        confidence = this.sigmoid(confidence, 0.5, 10);

        // Determine detection result
        const isCry = confidence >= this.cryConfidenceThreshold;
        const isHighConfidence = confidence >= this.highConfidenceThreshold;

        const inferenceTime = performance.now() - startTime;

        const result = {
            isCry,
            confidence,
            isHighConfidence,
            scores,
            threshold: this.cryConfidenceThreshold,
            inferenceTime,
            timestamp: new Date()
        };

        // Trigger callback
        if (this.onDetection) {
            this.onDetection(result);
        }

        return result;
    }

    /**
     * Score: Is fundamental frequency in infant vocal range?
     * Infants have F0 between 250-600 Hz
     */
    scoreF0InRange(features) {
        const f0 = features.dominantFrequency || 0;
        const { min, max } = this.infantF0Range;

        if (f0 >= min && f0 <= max) {
            // Perfect match
            return 1.0;
        }

        // Gradual falloff outside range
        if (f0 < min) {
            const distance = min - f0;
            return Math.max(0, 1 - distance / 200);
        }

        if (f0 > max) {
            const distance = f0 - max;
            return Math.max(0, 1 - distance / 400);
        }

        return 0;
    }

    /**
     * Score: Energy distribution in cry-relevant frequency bands
     */
    scoreHarmonicEnergy(features) {
        const centroid = features.spectralCentroid || 0;
        const rolloff = features.spectralRolloff || 0;

        // Cries have most energy between 500-3000 Hz
        // Centroid should be in 500-1500 Hz range for cries
        const centroidScore = this.gaussianScore(centroid, 500, 1500);

        // Rolloff (85% energy point) should be 2000-4000 Hz for cries
        const rolloffScore = this.gaussianScore(rolloff, 2000, 4000);

        return (centroidScore * 0.6 + rolloffScore * 0.4);
    }

    /**
     * Score: Spectral slope characteristic of cries
     * Cries have a specific spectral tilt (energy decreases at ~6dB/octave)
     */
    scoreSpectralSlope(features) {
        const centroid = features.spectralCentroid || 0;
        const rolloff = features.spectralRolloff || 0;

        // Calculate approximate slope from centroid to rolloff
        // Cries typically have moderate slope
        if (rolloff <= centroid || rolloff === 0) return 0.5;

        const ratio = rolloff / Math.max(centroid, 1);

        // Ideal ratio for cries is around 2-4
        if (ratio >= 2 && ratio <= 4) return 1.0;
        if (ratio >= 1.5 && ratio <= 5) return 0.7;

        return 0.3;
    }

    /**
     * Score: Temporal variation (cries have burst-pause patterns)
     * Uses attack time and RMS variation
     */
    scoreTemporalVariation(features) {
        const rms = features.rms || 0;
        const attackTime = features.attackTime || 0;

        // Cries have moderate-to-fast attack (0.05-0.3 seconds)
        let attackScore = 0;
        if (attackTime >= 0.05 && attackTime <= 0.3) {
            attackScore = 1.0;
        } else if (attackTime < 0.05) {
            attackScore = 0.6; // Too fast, might be impact sound
        } else {
            attackScore = Math.max(0, 1 - (attackTime - 0.3) / 0.5);
        }

        // RMS should be moderate for cries (not whisper quiet, not explosion loud)
        const rmsScore = this.gaussianScore(rms, 0.02, 0.15);

        return (attackScore * 0.5 + rmsScore * 0.5);
    }

    /**
     * Score: Cry-specific formant patterns
     * Infants have characteristic vocal tract resonances
     */
    scoreCryFormants(features) {
        const harmonicity = features.harmonicity || 0;
        const zeroCrossings = features.zeroCrossings || 0;

        // Cries have moderate harmonicity (0.2-0.6)
        // Pure tones = high harmonicity, noise = low
        const harmonicityScore = this.gaussianScore(harmonicity, 0.2, 0.6);

        // Normalize zero crossings (cries have moderate ZCR)
        const zcr = zeroCrossings / 15600; // Normalize by buffer size
        const zcrScore = this.gaussianScore(zcr, 0.05, 0.15);

        return (harmonicityScore * 0.6 + zcrScore * 0.4);
    }

    /**
     * Score: Penalize music-like characteristics
     * Music has high harmonicity, regular rhythm, distinct spectral peaks
     */
    scoreAntiMusic(features) {
        const harmonicity = features.harmonicity || 0;

        // Very high harmonicity (>0.7) suggests music
        let musicPenalty = 0;
        if (harmonicity > 0.7) {
            musicPenalty += (harmonicity - 0.7) / 0.3;
        }

        // Very low spectral centroid (<300 Hz) suggests bass music
        const centroid = features.spectralCentroid || 0;
        if (centroid < 300) {
            musicPenalty += 0.3;
        }

        // Return inverted score (high = not music-like)
        return Math.max(0, 1 - musicPenalty);
    }

    /**
     * Gaussian scoring function - returns 1.0 when value is in [min, max]
     */
    gaussianScore(value, min, max) {
        if (value >= min && value <= max) {
            return 1.0;
        }

        const center = (min + max) / 2;
        const sigma = (max - min) / 2;

        const distance = value < min ? min - value : value - max;
        return Math.exp(-(distance * distance) / (2 * sigma * sigma));
    }

    /**
     * Sigmoid function for smooth probability
     */
    sigmoid(x, center = 0.5, steepness = 10) {
        return 1 / (1 + Math.exp(-steepness * (x - center)));
    }

    /**
     * Get detection confidence level as string
     */
    getConfidenceLevel(confidence) {
        if (confidence >= 0.90) return 'Very High';
        if (confidence >= 0.80) return 'High';
        if (confidence >= 0.70) return 'Moderate';
        if (confidence >= 0.60) return 'Low';
        return 'Very Low';
    }

    /**
     * Set detection threshold
     */
    setThreshold(threshold) {
        this.cryConfidenceThreshold = Math.max(0.3, Math.min(0.95, threshold));
        console.log(`[CryDetector] Threshold set to ${this.cryConfidenceThreshold}`);
    }
}

// Export for use in other modules
window.CryDetector = CryDetector;
