import { Hono } from 'hono';
import type { Env, Baby, Track, DevelopmentalStage, AudioCategory } from '../types';
import { authMiddleware } from '../middleware/auth';
import { calculateAgeMonths, getDevelopmentalStage, getRateLimitKey, checkRateLimit } from '../utils/helpers';
import { callGeminiChat } from '../lib/gemini';

const ai = new Hono<{ Bindings: Env }>();

// All AI routes require authentication
ai.use('*', authMiddleware);

// Rate limit: 10 AI requests per minute per user/IP
ai.use('*', async (c, next) => {
  const identifier = c.get('userId') || c.req.header('CF-Connecting-IP') || 'anonymous';
  const key = getRateLimitKey(identifier, 'ai');
  const { allowed, remaining } = await checkRateLimit(c.env.CACHE, key, 10);

  c.header('X-RateLimit-Limit', '10');
  c.header('X-RateLimit-Remaining', remaining.toString());

  if (!allowed) {
    return c.json({ success: false, error: 'Rate limit exceeded', retry_after: 60 }, 429);
  }

  await next();
});

// System prompt for the baby soothing AI
const SYSTEM_PROMPT = `You are an expert pediatric sleep consultant and child development specialist AI assistant for the "Baby in Car" app. Your role is to provide personalized audio recommendations to calm babies during car rides.

You understand:
- Developmental stages from 0-36 months and appropriate audio for each stage
- The science of infant calming (white noise, rhythmic sounds, womb sounds)
- How different sounds affect babies at different ages
- Emergency cry-stopping techniques
- Safe driving considerations for parents

When recommending content, consider:
- Baby's exact age in months and developmental stage
- Current mood/state (crying, fussy, sleepy, playful, calm)
- Time of day and trip duration
- Previously effective tracks for this specific baby
- Audio categories: white noise, nature sounds, classical music, lullabies, fairy tales

Always respond in JSON format with structured recommendations.`;

// POST /ai/recommend - Get AI-powered personalized recommendations
ai.post('/recommend', async (c) => {
  if (!c.env.GEMINI_API_KEY) {
    return c.json({ error: 'AI features temporarily unavailable' }, 503);
  }
  const userId = c.get('userId');
  const body = await c.req.json<{
    baby_id: string;
    mood?: string;
    trip_duration_minutes?: number;
    time_of_day?: 'morning' | 'afternoon' | 'evening' | 'night';
    context?: string;
  }>();

  if (!body.baby_id) {
    return c.json({ success: false, error: 'Baby ID required' }, 400);
  }

  // Get baby details
  const baby = await c.env.DB.prepare(`
    SELECT * FROM babies WHERE id = ? AND user_id = ?
  `).bind(body.baby_id, userId).first<Baby>();

  if (!baby) {
    return c.json({ success: false, error: 'Baby not found' }, 404);
  }

  const ageMonths = calculateAgeMonths(baby.birth_date);
  const stage = getDevelopmentalStage(ageMonths);
  const preferences = typeof baby.preferences === 'string'
    ? JSON.parse(baby.preferences)
    : baby.preferences;

  // Get available tracks for this age
  const tracksResult = await c.env.DB.prepare(`
    SELECT * FROM tracks
    WHERE age_range_min <= ? AND age_range_max >= ?
    ORDER BY calming_score DESC
    LIMIT 50
  `).bind(ageMonths, ageMonths).all<Track>();

  const availableTracks = tracksResult.results;
  const effectiveTracks = preferences.effective_tracks || [];

  // Build the prompt for AI
  const userPrompt = `
Baby Profile:
- Name: ${baby.name}
- Age: ${ageMonths} months
- Developmental Stage: ${stage}
- Previously Effective Tracks: ${effectiveTracks.length > 0 ? effectiveTracks.slice(0, 5).join(', ') : 'None yet'}
- Favorite Categories: ${preferences.favorite_categories?.join(', ') || 'Not established'}

Current Situation:
- Mood: ${body.mood || 'unknown'}
- Trip Duration: ${body.trip_duration_minutes || 'unknown'} minutes
- Time of Day: ${body.time_of_day || 'unknown'}
- Additional Context: ${body.context || 'none'}

Available Audio Categories: classical_music, fairy_tales, white_noise, nature_sounds, instrumental, children_songs, podcasts

Available Tracks (sample):
${availableTracks.slice(0, 15).map(t => `- ${t.title} (${t.category}, calming: ${t.calming_score})`).join('\n')}

Please provide personalized recommendations in the following JSON format:
{
  "primary_recommendation": {
    "category": "category_name",
    "reasoning": "brief explanation",
    "suggested_tracks": ["track_id1", "track_id2"],
    "expected_effectiveness": 0.0-1.0
  },
  "alternative_recommendations": [
    {"category": "category_name", "reasoning": "brief explanation"}
  ],
  "calming_strategy": {
    "approach": "description of approach",
    "phases": ["phase1", "phase2", "phase3"],
    "estimated_calming_time_minutes": number
  },
  "tips_for_parent": ["tip1", "tip2"],
  "warning_signs": ["sign1", "sign2"]
}
`;

  try {
    // Call Gemini 2.0 Flash
    const responseText = await callGeminiChat(
      c.env.GEMINI_API_KEY,
      SYSTEM_PROMPT,
      userPrompt,
      1024,
    );

    // Parse AI response
    let aiRecommendation;
    try {
      const jsonMatch = responseText.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        aiRecommendation = JSON.parse(jsonMatch[0]);
      } else {
        throw new Error('No JSON found in response');
      }
    } catch {
      // Fallback to structured response if parsing fails
      aiRecommendation = {
        primary_recommendation: {
          category: getDefaultCategory(stage, body.mood),
          reasoning: 'Based on developmental stage and mood analysis',
          suggested_tracks: availableTracks.slice(0, 3).map(t => t.id),
          expected_effectiveness: 0.75
        },
        alternative_recommendations: [
          { category: 'white_noise', reasoning: 'Universal calming effect' }
        ],
        calming_strategy: {
          approach: 'Gradual soothing with age-appropriate sounds',
          phases: ['Attention', 'Transition', 'Sustained'],
          estimated_calming_time_minutes: 5
        },
        tips_for_parent: ['Keep volume at safe levels', 'Maintain consistent sound'],
        warning_signs: ['Continued crying after 10 minutes', 'Signs of discomfort']
      };
    }

    // Map recommendations to actual tracks
    const recommendedTracks = mapRecommendationsToTracks(
      aiRecommendation,
      availableTracks,
      effectiveTracks
    );

    return c.json({
      success: true,
      baby: {
        name: baby.name,
        age_months: ageMonths,
        stage,
      },
      ai_recommendation: aiRecommendation,
      recommended_tracks: recommendedTracks,
      model_used: 'gemini-2.0-flash',
    });
  } catch (error) {
    console.error('AI recommendation failed:', error);

    // Fallback to rule-based recommendations
    const fallbackTracks = getFallbackRecommendations(availableTracks, stage, body.mood);

    return c.json({
      success: true,
      baby: {
        name: baby.name,
        age_months: ageMonths,
        stage,
      },
      ai_recommendation: null,
      fallback_used: true,
      recommended_tracks: fallbackTracks,
      error_message: 'AI unavailable, using rule-based recommendations',
    });
  }
});

// POST /ai/emergency-advice - Get AI advice for emergency cry-stop
ai.post('/emergency-advice', async (c) => {
  if (!c.env.GEMINI_API_KEY) {
    return c.json({ error: 'AI features temporarily unavailable' }, 503);
  }
  const userId = c.get('userId');
  const body = await c.req.json<{
    baby_id: string;
    crying_duration_minutes?: number;
    intensity?: 'mild' | 'moderate' | 'severe';
    tried_sounds?: string[];
  }>();

  if (!body.baby_id) {
    return c.json({ success: false, error: 'Baby ID required' }, 400);
  }

  const baby = await c.env.DB.prepare(`
    SELECT * FROM babies WHERE id = ? AND user_id = ?
  `).bind(body.baby_id, userId).first<Baby>();

  if (!baby) {
    return c.json({ success: false, error: 'Baby not found' }, 404);
  }

  const ageMonths = calculateAgeMonths(baby.birth_date);
  const stage = getDevelopmentalStage(ageMonths);

  const emergencyPrompt = `
URGENT: Baby is crying in car and parent needs immediate help.

Baby: ${baby.name}, ${ageMonths} months old (${stage} stage)
Crying Duration: ${body.crying_duration_minutes || 'unknown'} minutes
Intensity: ${body.intensity || 'unknown'}
Already Tried: ${body.tried_sounds?.join(', ') || 'nothing yet'}

Provide IMMEDIATE actionable advice in JSON format:
{
  "immediate_action": "single most important action right now",
  "sound_sequence": [
    {"sound": "sound_type", "duration_seconds": number, "volume": "low/medium"}
  ],
  "calming_technique": "brief technique description",
  "safety_reminder": "driving safety reminder",
  "when_to_stop": "guidance on when to pull over",
  "expected_result": "what to expect"
}
`;

  try {
    const responseText = await callGeminiChat(
      c.env.GEMINI_API_KEY,
      SYSTEM_PROMPT,
      emergencyPrompt,
      512,
    );

    let advice;
    try {
      const jsonMatch = responseText.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        advice = JSON.parse(jsonMatch[0]);
      } else {
        throw new Error('No JSON found');
      }
    } catch {
      // Emergency fallback
      advice = getEmergencyFallback(ageMonths, body.intensity);
    }

    return c.json({
      success: true,
      emergency_advice: advice,
      recommended_generator: getEmergencyGenerator(ageMonths),
    });
  } catch (error) {
    console.error('Emergency AI advice failed:', error);

    return c.json({
      success: true,
      emergency_advice: getEmergencyFallback(ageMonths, body.intensity),
      recommended_generator: getEmergencyGenerator(ageMonths),
      fallback_used: true,
    });
  }
});

// POST /ai/analyze-effectiveness - Analyze why certain tracks work
ai.post('/analyze-effectiveness', async (c) => {
  if (!c.env.GEMINI_API_KEY) {
    return c.json({ error: 'AI features temporarily unavailable' }, 503);
  }
  const userId = c.get('userId');
  const body = await c.req.json<{
    baby_id: string;
  }>();

  if (!body.baby_id) {
    return c.json({ success: false, error: 'Baby ID required' }, 400);
  }

  const baby = await c.env.DB.prepare(`
    SELECT * FROM babies WHERE id = ? AND user_id = ?
  `).bind(body.baby_id, userId).first<Baby>();

  if (!baby) {
    return c.json({ success: false, error: 'Baby not found' }, 404);
  }

  const ageMonths = calculateAgeMonths(baby.birth_date);
  const stage = getDevelopmentalStage(ageMonths);

  // Get effectiveness data
  const effectivenessData = await c.env.DB.prepare(`
    SELECT te.track_id, te.was_effective, te.calming_time_seconds, te.context,
           t.title, t.category, t.calming_score, t.tempo_bpm
    FROM track_effectiveness te
    JOIN tracks t ON te.track_id = t.id
    WHERE te.baby_id = ?
    ORDER BY te.created_at DESC
    LIMIT 50
  `).bind(body.baby_id).all();

  if (effectivenessData.results.length === 0) {
    return c.json({
      success: true,
      analysis: {
        message: 'Not enough data yet. Keep using the app to build personalized insights!',
        recommendation: 'Try different sound categories to discover what works best.'
      }
    });
  }

  const analysisPrompt = `
Analyze this baby's audio effectiveness data and provide insights:

Baby: ${baby.name}, ${ageMonths} months old (${stage})

Effectiveness Data:
${effectivenessData.results.map((e: any) =>
  `- ${e.title} (${e.category}): ${e.was_effective ? 'EFFECTIVE' : 'NOT EFFECTIVE'}, calming time: ${e.calming_time_seconds}s, context: ${e.context}`
).join('\n')}

Provide analysis in JSON format:
{
  "patterns_identified": ["pattern1", "pattern2"],
  "most_effective_characteristics": {
    "categories": ["cat1"],
    "tempo_range": "description",
    "best_contexts": ["context1"]
  },
  "insights": "2-3 sentence personalized insight",
  "recommendations": ["rec1", "rec2"],
  "developmental_note": "how this relates to their stage"
}
`;

  try {
    const responseText = await callGeminiChat(
      c.env.GEMINI_API_KEY,
      SYSTEM_PROMPT,
      analysisPrompt,
      768,
    );

    let analysis;
    try {
      const jsonMatch = responseText.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        analysis = JSON.parse(jsonMatch[0]);
      } else {
        throw new Error('No JSON found');
      }
    } catch {
      analysis = generateRuleBasedAnalysis(effectivenessData.results, stage);
    }

    return c.json({
      success: true,
      baby: {
        name: baby.name,
        age_months: ageMonths,
        stage,
      },
      analysis,
      data_points_analyzed: effectivenessData.results.length,
    });
  } catch (error) {
    console.error('Effectiveness analysis failed:', error);

    return c.json({
      success: true,
      analysis: generateRuleBasedAnalysis(effectivenessData.results, stage),
      fallback_used: true,
    });
  }
});

// POST /ai/generate-story - Generate a custom bedtime story
ai.post('/generate-story', async (c) => {
  if (!c.env.GEMINI_API_KEY) {
    return c.json({ error: 'AI features temporarily unavailable' }, 503);
  }
  const userId = c.get('userId');
  const user = c.get('user');

  // Check premium status
  if (user.subscription_status === 'free') {
    return c.json({
      success: false,
      error: 'Premium subscription required for custom stories',
      upgrade_required: true
    }, 403);
  }

  const body = await c.req.json<{
    baby_id: string;
    theme?: string;
    include_name?: boolean;
    length?: 'short' | 'medium' | 'long';
  }>();

  if (!body.baby_id) {
    return c.json({ success: false, error: 'Baby ID required' }, 400);
  }

  const baby = await c.env.DB.prepare(`
    SELECT * FROM babies WHERE id = ? AND user_id = ?
  `).bind(body.baby_id, userId).first<Baby>();

  if (!baby) {
    return c.json({ success: false, error: 'Baby not found' }, 404);
  }

  const ageMonths = calculateAgeMonths(baby.birth_date);

  // Only generate stories for babies 12+ months (language comprehension)
  if (ageMonths < 12) {
    return c.json({
      success: false,
      error: 'Custom stories are best for babies 12 months and older',
      recommendation: 'Try soothing sounds instead for younger babies'
    }, 400);
  }

  const lengthGuide = {
    short: '100-150 words, about 1 minute',
    medium: '200-300 words, about 2-3 minutes',
    long: '400-500 words, about 4-5 minutes'
  };

  const storyPrompt = `
Generate a soothing bedtime story for a baby in a car:

Baby Name: ${body.include_name !== false ? baby.name : 'little one'}
Age: ${ageMonths} months
Theme: ${body.theme || 'gentle adventure'}
Length: ${lengthGuide[body.length || 'short']}

Requirements:
- Use simple, repetitive language appropriate for the age
- Include calming elements (soft clouds, gentle waves, sleepy animals)
- Avoid exciting or scary elements
- Include rhythmic, lullaby-like sentences
- End with falling asleep peacefully

Generate ONLY the story text, ready to be read aloud or converted to speech.
`;

  try {
    const story = await callGeminiChat(
      c.env.GEMINI_API_KEY,
      'You are a children\'s author specializing in soothing bedtime stories for babies and toddlers. Write gentle, calming stories with simple vocabulary.',
      storyPrompt,
      body.length === 'long' ? 700 : body.length === 'medium' ? 450 : 250,
    );

    return c.json({
      success: true,
      story: {
        text: story.trim(),
        theme: body.theme || 'gentle adventure',
        length: body.length || 'short',
        personalized: body.include_name !== false,
        estimated_duration_seconds: estimateReadingTime(story),
      }
    });
  } catch (error) {
    console.error('Story generation failed:', error);

    return c.json({
      success: false,
      error: 'Story generation temporarily unavailable',
    }, 503);
  }
});

// Helper functions
function getDefaultCategory(stage: DevelopmentalStage, mood?: string): AudioCategory {
  if (mood === 'crying' || mood === 'fussy') {
    return 'white_noise';
  }

  const stageDefaults: Record<DevelopmentalStage, AudioCategory> = {
    fourth_trimester: 'white_noise',
    early_regulation: 'white_noise',
    sensory_exploration: 'nature_sounds',
    motor_development: 'instrumental',
    vocabulary_burst: 'children_songs',
    sentence_building: 'fairy_tales',
    imagination_growth: 'fairy_tales',
  };

  return stageDefaults[stage] || 'white_noise';
}

function mapRecommendationsToTracks(
  aiRec: any,
  availableTracks: Track[],
  effectiveTracks: string[]
): Track[] {
  const category = aiRec?.primary_recommendation?.category;

  // Prioritize previously effective tracks
  const effective = availableTracks.filter(t => effectiveTracks.includes(t.id));

  // Then tracks matching recommended category
  const categoryMatch = availableTracks.filter(t =>
    t.category === category && !effectiveTracks.includes(t.id)
  );

  // Then highest calming score
  const remaining = availableTracks.filter(t =>
    !effectiveTracks.includes(t.id) && t.category !== category
  );

  return [...effective, ...categoryMatch, ...remaining].slice(0, 10);
}

function getFallbackRecommendations(
  tracks: Track[],
  stage: DevelopmentalStage,
  mood?: string
): Track[] {
  let filtered = [...tracks];

  if (mood === 'crying' || mood === 'fussy') {
    filtered = filtered.filter(t =>
      t.category === 'white_noise' || t.calming_score >= 0.8
    );
  }

  return filtered
    .sort((a, b) => b.calming_score - a.calming_score)
    .slice(0, 10);
}

function getEmergencyGenerator(ageMonths: number): string {
  if (ageMonths < 3) return 'shushing';
  if (ageMonths < 6) return 'womb';
  if (ageMonths < 12) return 'pinkNoise';
  return 'rain';
}

function getEmergencyFallback(ageMonths: number, intensity?: string): any {
  const generator = getEmergencyGenerator(ageMonths);

  return {
    immediate_action: 'Start playing ' + generator + ' sound immediately',
    sound_sequence: [
      { sound: generator, duration_seconds: 30, volume: 'medium' },
      { sound: 'pinkNoise', duration_seconds: 60, volume: 'low' },
    ],
    calming_technique: ageMonths < 6
      ? 'Shushing mimics womb sounds - familiar and calming for young babies'
      : 'Consistent, rhythmic sounds help regulate nervous system',
    safety_reminder: 'If baby continues crying intensely for more than 15 minutes, consider safely pulling over',
    when_to_stop: 'If baby shows signs of distress beyond normal crying, or if you need to focus on driving',
    expected_result: 'Most babies begin to calm within 2-5 minutes of consistent sound'
  };
}

function generateRuleBasedAnalysis(data: any[], stage: DevelopmentalStage): any {
  const effective = data.filter((d: any) => d.was_effective);
  const categories = effective.reduce((acc: any, d: any) => {
    acc[d.category] = (acc[d.category] || 0) + 1;
    return acc;
  }, {});

  const topCategory = Object.entries(categories)
    .sort((a: any, b: any) => b[1] - a[1])[0]?.[0] || 'white_noise';

  return {
    patterns_identified: [
      `${topCategory} appears most effective`,
      `Average calming time: ${Math.round(effective.reduce((s: number, d: any) => s + d.calming_time_seconds, 0) / effective.length || 0)} seconds`
    ],
    most_effective_characteristics: {
      categories: [topCategory],
      tempo_range: 'Slower tempos preferred',
      best_contexts: ['crying', 'fussy']
    },
    insights: `Based on ${data.length} listening sessions, your baby responds best to ${topCategory}. This is typical for the ${stage} developmental stage.`,
    recommendations: [
      `Continue using ${topCategory} as primary`,
      'Try varying volume levels',
      'Experiment with similar categories'
    ],
    developmental_note: `At the ${stage} stage, babies typically respond well to consistent, rhythmic sounds.`
  };
}

function estimateReadingTime(text: string): number {
  // Average speaking rate for bedtime stories: ~120 words per minute
  const words = text.split(/\s+/).length;
  return Math.round((words / 120) * 60);
}

export default ai;
