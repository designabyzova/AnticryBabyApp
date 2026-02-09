/**
 * CryClassifier - Baby cry type classification (Stage 2)
 *
 * This is Stage 2 of the two-stage detection pipeline.
 * It only runs AFTER CryDetector (Stage 1) confirms this IS a baby cry.
 *
 * Classifies baby cries into 6 types:
 * - Hunger: rhythmic, repetitive, moderate pitch, rising-falling pattern
 * - Tired: whiny, fussy, gradually increasing, lower energy
 * - Pain: sudden, high-pitched, intense, fast attack
 * - Attention: intermittent, varied, stops and starts
 * - Discomfort: squirming sounds, irregular, moderate intensity
 * - General: doesn't fit other categories clearly
 *
 * Since Stage 1 already confirmed this is a cry, this classifier
 * can use more aggressive discrimination between cry types.
 */

class CryClassifier {
    constructor() {
        // Cry types matching DeepInfant V2
        this.cryTypes = [
            'hunger',
            'tired',
            'pain',
            'attention',
            'discomfort',
            'general'
        ];

        // Cry type icons for UI
        this.cryTypeIcons = {
            hunger: '🍼',
            tired: '😴',
            pain: '😣',
            attention: '👋',
            discomfort: '😖',
            general: '😢',
            unknown: '👶'
        };

        // Cry type descriptions
        this.cryTypeDescriptions = {
            hunger: 'Baby is hungry - rhythmic, repetitive cry',
            tired: 'Baby is tired - whiny, fussy cry that builds up',
            pain: 'Baby is in pain - sudden, high-pitched, intense cry',
            attention: 'Baby wants attention - intermittent, stops when attended',
            discomfort: 'Baby is uncomfortable - irregular, squirming sounds',
            general: 'General fussiness - could be multiple causes',
            unknown: 'Waiting for audio input...'
        };

        // Classification thresholds
        this.minimumConfidenceThreshold = 0.35; // Lower threshold since Stage 1 confirms cry
        this.highConfidenceThreshold = 0.50;

        // Improved feature profiles with more distinct ranges
        // These profiles are now more discriminative since we know it's a cry
        this.featureProfiles = {
            hunger: {
                // Hunger cries: moderate pitch, rhythmic, sustained energy
                spectralCentroid: { ideal: 550, tolerance: 150, weight: 0.25 },
                dominantFrequency: { ideal: 400, tolerance: 100, weight: 0.20 },
                harmonicity: { ideal: 0.45, tolerance: 0.15, weight: 0.20 },
                attackTime: { ideal: 0.15, tolerance: 0.08, weight: 0.15 },
                intensity: { ideal: 0.5, tolerance: 0.2, weight: 0.20 }
            },
            tired: {
                // Tired cries: lower pitch, whiny, gradual onset, lower energy
                spectralCentroid: { ideal: 400, tolerance: 100, weight: 0.25 },
                dominantFrequency: { ideal: 320, tolerance: 80, weight: 0.20 },
                harmonicity: { ideal: 0.35, tolerance: 0.15, weight: 0.15 },
                attackTime: { ideal: 0.35, tolerance: 0.15, weight: 0.20 },
                intensity: { ideal: 0.35, tolerance: 0.15, weight: 0.20 }
            },
            pain: {
                // Pain cries: high pitch, sudden onset, intense, loud
                spectralCentroid: { ideal: 800, tolerance: 200, weight: 0.30 },
                dominantFrequency: { ideal: 550, tolerance: 100, weight: 0.25 },
                harmonicity: { ideal: 0.25, tolerance: 0.15, weight: 0.10 },
                attackTime: { ideal: 0.05, tolerance: 0.03, weight: 0.20 },
                intensity: { ideal: 0.85, tolerance: 0.15, weight: 0.15 }
            },
            attention: {
                // Attention cries: variable, intermittent, moderate pitch
                spectralCentroid: { ideal: 500, tolerance: 150, weight: 0.20 },
                dominantFrequency: { ideal: 380, tolerance: 100, weight: 0.15 },
                harmonicity: { ideal: 0.40, tolerance: 0.20, weight: 0.25 },
                attackTime: { ideal: 0.20, tolerance: 0.10, weight: 0.20 },
                intensity: { ideal: 0.45, tolerance: 0.20, weight: 0.20 }
            },
            discomfort: {
                // Discomfort cries: irregular, squirmy, moderate-high pitch
                spectralCentroid: { ideal: 650, tolerance: 200, weight: 0.25 },
                dominantFrequency: { ideal: 450, tolerance: 100, weight: 0.20 },
                harmonicity: { ideal: 0.30, tolerance: 0.15, weight: 0.15 },
                attackTime: { ideal: 0.10, tolerance: 0.05, weight: 0.20 },
                intensity: { ideal: 0.60, tolerance: 0.20, weight: 0.20 }
            },
            general: {
                // General: broad ranges, catch-all category
                spectralCentroid: { ideal: 550, tolerance: 250, weight: 0.20 },
                dominantFrequency: { ideal: 400, tolerance: 150, weight: 0.15 },
                harmonicity: { ideal: 0.40, tolerance: 0.25, weight: 0.20 },
                attackTime: { ideal: 0.15, tolerance: 0.10, weight: 0.20 },
                intensity: { ideal: 0.50, tolerance: 0.25, weight: 0.25 }
            }
        };

        // Performance tracking
        this.inferenceTimeHistory = [];
        this.maxHistorySize = 100;

        // Callbacks
        this.onClassification = null;

        console.log('[CryClassifier] Stage 2 initialized - 6 cry types');
    }

    /**
     * Classify cry type from audio features
     * @param {Object} features - Audio features extracted by AudioProcessor
     * @returns {Object} Classification result with cry type and probabilities
     */
    classify(features) {
        const startTime = performance.now();

        // Normalize features for classification
        const normalized = this.normalizeInputFeatures(features);

        // Calculate scores for each cry type
        const scores = {};
        let totalScore = 0;

        for (const cryType of this.cryTypes) {
            const score = this.calculateTypeScore(normalized, cryType);
            scores[cryType] = score;
            totalScore += score;
        }

        // Apply softmax for better probability distribution
        const probabilities = this.softmax(scores, 2.0); // Temperature 2.0 for sharper distribution

        // Find the most likely cry type
        let maxProb = 0;
        let predictedType = 'general';

        for (const cryType of this.cryTypes) {
            if (probabilities[cryType] > maxProb) {
                maxProb = probabilities[cryType];
                predictedType = cryType;
            }
        }

        // Determine confidence level
        const isConfident = maxProb >= this.minimumConfidenceThreshold;
        const isHighConfidence = maxProb >= this.highConfidenceThreshold;

        // Record inference time
        const inferenceTime = performance.now() - startTime;
        this.recordInferenceTime(inferenceTime);

        const result = {
            cryType: predictedType,
            confidence: maxProb,
            probabilities: probabilities,
            timestamp: new Date(),
            isConfident: isConfident,
            isHighConfidence: isHighConfidence,
            inferenceTime: inferenceTime,
            features: this.normalizeFeatures(features)
        };

        // Trigger callback
        if (this.onClassification) {
            this.onClassification(result);
        }

        return result;
    }

    /**
     * Normalize input features for classification
     */
    normalizeInputFeatures(features) {
        return {
            spectralCentroid: features.spectralCentroid || 0,
            dominantFrequency: features.dominantFrequency || 0,
            harmonicity: features.harmonicity || 0,
            attackTime: features.attackTime || 0,
            intensity: Math.min(1, (features.rms || 0) * 10) // Normalize RMS to 0-1
        };
    }

    /**
     * Calculate score for a specific cry type based on features
     */
    calculateTypeScore(features, cryType) {
        const profile = this.featureProfiles[cryType];
        let weightedScore = 0;
        let totalWeight = 0;

        // Spectral centroid match
        if (profile.spectralCentroid) {
            const score = this.gaussianScore(
                features.spectralCentroid,
                profile.spectralCentroid.ideal,
                profile.spectralCentroid.tolerance
            );
            weightedScore += score * profile.spectralCentroid.weight;
            totalWeight += profile.spectralCentroid.weight;
        }

        // Dominant frequency match
        if (profile.dominantFrequency) {
            const score = this.gaussianScore(
                features.dominantFrequency,
                profile.dominantFrequency.ideal,
                profile.dominantFrequency.tolerance
            );
            weightedScore += score * profile.dominantFrequency.weight;
            totalWeight += profile.dominantFrequency.weight;
        }

        // Harmonicity match
        if (profile.harmonicity) {
            const score = this.gaussianScore(
                features.harmonicity,
                profile.harmonicity.ideal,
                profile.harmonicity.tolerance
            );
            weightedScore += score * profile.harmonicity.weight;
            totalWeight += profile.harmonicity.weight;
        }

        // Attack time match
        if (profile.attackTime) {
            const score = this.gaussianScore(
                features.attackTime,
                profile.attackTime.ideal,
                profile.attackTime.tolerance
            );
            weightedScore += score * profile.attackTime.weight;
            totalWeight += profile.attackTime.weight;
        }

        // Intensity match
        if (profile.intensity) {
            const score = this.gaussianScore(
                features.intensity,
                profile.intensity.ideal,
                profile.intensity.tolerance
            );
            weightedScore += score * profile.intensity.weight;
            totalWeight += profile.intensity.weight;
        }

        // Return normalized score
        return totalWeight > 0 ? weightedScore / totalWeight : 0;
    }

    /**
     * Gaussian scoring function
     * Returns 1.0 at ideal value, decreases with distance
     */
    gaussianScore(value, ideal, tolerance) {
        const distance = Math.abs(value - ideal);
        const sigma = tolerance;

        // Gaussian falloff
        return Math.exp(-(distance * distance) / (2 * sigma * sigma));
    }

    /**
     * Softmax function for probability distribution
     * @param {Object} scores - Raw scores per class
     * @param {number} temperature - Higher = sharper distribution
     */
    softmax(scores, temperature = 1.0) {
        const types = Object.keys(scores);
        const scaledScores = {};
        let maxScore = -Infinity;

        // Scale by temperature and find max
        for (const type of types) {
            scaledScores[type] = scores[type] / temperature;
            if (scaledScores[type] > maxScore) {
                maxScore = scaledScores[type];
            }
        }

        // Compute exp(score - max) for numerical stability
        let sumExp = 0;
        const expScores = {};
        for (const type of types) {
            expScores[type] = Math.exp(scaledScores[type] - maxScore);
            sumExp += expScores[type];
        }

        // Normalize to probabilities
        const probabilities = {};
        for (const type of types) {
            probabilities[type] = expScores[type] / sumExp;
        }

        return probabilities;
    }

    /**
     * Normalize features for display/debugging
     */
    normalizeFeatures(features) {
        return {
            spectralCentroid: Math.round(features.spectralCentroid || 0),
            spectralRolloff: Math.round(features.spectralRolloff || 0),
            dominantFrequency: Math.round(features.dominantFrequency || 0),
            rms: (features.rms || 0).toFixed(4),
            zeroCrossings: Math.round(features.zeroCrossings || 0),
            harmonicity: (features.harmonicity || 0).toFixed(3),
            attackTime: ((features.attackTime || 0) * 1000).toFixed(1) + 'ms'
        };
    }

    /**
     * Record inference time for performance monitoring
     */
    recordInferenceTime(timeMs) {
        this.inferenceTimeHistory.push(timeMs);
        if (this.inferenceTimeHistory.length > this.maxHistorySize) {
            this.inferenceTimeHistory.shift();
        }
    }

    /**
     * Get performance statistics
     */
    getPerformanceStats() {
        if (this.inferenceTimeHistory.length === 0) {
            return { average: 0, min: 0, max: 0, count: 0 };
        }

        const sum = this.inferenceTimeHistory.reduce((a, b) => a + b, 0);
        return {
            average: sum / this.inferenceTimeHistory.length,
            min: Math.min(...this.inferenceTimeHistory),
            max: Math.max(...this.inferenceTimeHistory),
            count: this.inferenceTimeHistory.length
        };
    }

    /**
     * Get icon for cry type
     */
    getIcon(cryType) {
        return this.cryTypeIcons[cryType] || this.cryTypeIcons.unknown;
    }

    /**
     * Get description for cry type
     */
    getDescription(cryType) {
        return this.cryTypeDescriptions[cryType] || this.cryTypeDescriptions.unknown;
    }

    /**
     * Get all cry types
     */
    getCryTypes() {
        return this.cryTypes;
    }

    /**
     * Create a mock classification result for testing
     */
    static mockResult(cryType, confidence = 0.85) {
        const probabilities = {};
        const types = ['hunger', 'tired', 'pain', 'attention', 'discomfort', 'general'];

        // Distribute remaining probability among other types
        const remaining = 1 - confidence;
        const otherTypes = types.filter(t => t !== cryType);
        const otherProb = remaining / otherTypes.length;

        for (const type of types) {
            probabilities[type] = type === cryType ? confidence : otherProb;
        }

        return {
            cryType: cryType,
            confidence: confidence,
            probabilities: probabilities,
            timestamp: new Date(),
            isConfident: confidence >= 0.35,
            isHighConfidence: confidence >= 0.50,
            inferenceTime: Math.random() * 10 + 5,
            features: {
                spectralCentroid: Math.round(Math.random() * 500 + 400),
                spectralRolloff: Math.round(Math.random() * 2000 + 1500),
                dominantFrequency: Math.round(Math.random() * 300 + 300),
                rms: (Math.random() * 0.1).toFixed(4),
                zeroCrossings: Math.round(Math.random() * 1000 + 500),
                harmonicity: (Math.random() * 0.5 + 0.2).toFixed(3),
                attackTime: (Math.random() * 100 + 50).toFixed(1) + 'ms'
            }
        };
    }
}

// Export for use in other modules
window.CryClassifier = CryClassifier;
