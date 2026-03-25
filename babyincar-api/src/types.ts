// Environment bindings
export interface Env {
  DB: D1Database;
  SESSIONS: KVNamespace;
  CACHE: KVNamespace;
  AUDIO_BUCKET: R2Bucket;
  IMAGES_BUCKET: R2Bucket;
  GEMINI_API_KEY: string;  // Gemini 2.0 Flash — primary AI provider (free tier)
  ENVIRONMENT: string;
  JWT_SECRET: string;
  APPLE_TEAM_ID: string;
  APPLE_KEY_ID: string;
  APPLE_PRIVATE_KEY: string;
  APP_STORE_SHARED_SECRET: string;
  // Audio curation API keys (optional - for automated collection)
  FREESOUND_API_KEY?: string;
  PIXABAY_API_KEY?: string;
  // AI Music Generation API keys
  SUNO_API_KEY?: string;
  AIML_API_KEY?: string;
}

// User types
export interface User {
  id: string;
  email: string;
  name: string | null;
  auth_provider: 'email' | 'apple';
  apple_user_id: string | null;
  subscription_status: 'free' | 'premium' | 'family';
  subscription_expires_at: string | null;
  created_at: string;
  updated_at: string;
}

export interface UserSettings {
  notifications_enabled: boolean;
  auto_play_carplay: boolean;
  max_volume_db: number;
  default_sleep_timer_minutes: number;
  preferred_languages: string[];
  theme: 'light' | 'dark' | 'auto';
}

// Baby types
export interface Baby {
  id: string;
  user_id: string;
  name: string;
  birth_date: string;
  photo_url: string | null;
  preferences: BabyPreferences;
  created_at: string;
  updated_at: string;
}

export interface BabyPreferences {
  favorite_categories: string[];
  preferred_languages: string[];
  effective_tracks: string[];
}

export interface BabyWithAge extends Baby {
  age_months: number;
  developmental_stage: DevelopmentalStage;
}

export type DevelopmentalStage =
  | 'fourth_trimester'      // 0-3 months
  | 'early_regulation'      // 3-6 months
  | 'sensory_exploration'   // 6-9 months
  | 'motor_development'     // 9-12 months
  | 'vocabulary_burst'      // 12-18 months
  | 'sentence_building'     // 18-24 months
  | 'imagination_growth';   // 24-36 months

// Audio content types
export interface Track {
  id: string;
  title: string;
  artist: string;
  category: AudioCategory;
  language: string;
  duration: number;
  age_range_min: number;
  age_range_max: number;
  tempo_bpm: number | null;
  calming_score: number;
  audio_source_type: 'generated' | 'recorded' | 'text_to_speech';
  generator_type: string | null;
  stream_url: string | null;
  artwork_url: string | null;
  is_premium: boolean;
  created_at: string;
}

export type AudioCategory =
  | 'classical_music'
  | 'fairy_tales'
  | 'white_noise'
  | 'nature_sounds'
  | 'instrumental'
  | 'children_songs'
  | 'podcasts';

export interface Playlist {
  id: string;
  name: string;
  description: string;
  category: AudioCategory | null;
  target_age_months: number | null;
  artwork_url: string | null;
  is_system: boolean;
  track_count?: number;
  total_duration?: number;
  tracks?: Track[];
  created_at: string;
}

// Analytics types
export interface PlaybackEvent {
  id: string;
  user_id: string;
  baby_id: string | null;
  track_id: string;
  event_type: 'play' | 'pause' | 'complete' | 'skip';
  position_seconds: number;
  context: 'home' | 'carplay' | 'emergency';
  session_id: string;
  created_at: string;
}

export interface TrackEffectiveness {
  id: string;
  baby_id: string;
  track_id: string;
  was_effective: boolean;
  calming_time_seconds: number;
  context: 'crying' | 'fussy' | 'sleepy';
  emergency_mode: boolean;
  created_at: string;
}

export interface EmergencySession {
  id: string;
  user_id: string;
  baby_id: string;
  started_at: string;
  ended_at: string | null;
  phases_completed: string[];
  was_successful: boolean | null;
  tracks_used: string[];
  created_at: string;
}

export interface BabyInsights {
  total_listening_time_minutes: number;
  most_effective_category: AudioCategory | null;
  most_effective_tracks: Array<{
    track_id: string;
    success_rate: number;
  }>;
  average_calming_time_seconds: number;
  emergency_mode_usage: {
    total_activations: number;
    success_rate: number;
  };
}

// Subscription types
export interface Subscription {
  product_id: string;
  expires_at: string;
  is_trial: boolean;
  will_renew: boolean;
}

export interface SubscriptionVerification {
  valid: boolean;
  subscription: Subscription | null;
  entitlements: string[];
}

// Auth types
export interface AuthPayload {
  user_id: string;
  email: string;
  exp: number;
  iat: number;
}

export interface Session {
  id: string;
  user_id: string;
  token_hash: string;
  expires_at: string;
  created_at: string;
}

// API Response types
export interface ApiResponse<T = unknown> {
  success: boolean;
  data?: T;
  error?: string;
  message?: string;
}

// Request types
export interface RegisterRequest {
  email: string;
  password?: string;
  name?: string;
  auth_provider: 'email' | 'apple';
  apple_id_token?: string;
}

export interface LoginRequest {
  email: string;
  password: string;
}

export interface CreateBabyRequest {
  name: string;
  birth_date: string;
  photo_data?: string;
}

export interface UpdateBabyRequest {
  name?: string;
  birth_date?: string;
  photo_data?: string;
}

export interface RecordPlaybackRequest {
  baby_id?: string;
  track_id: string;
  event_type: 'play' | 'pause' | 'complete' | 'skip';
  position_seconds: number;
  session_id: string;
  context: 'home' | 'carplay' | 'emergency';
}

export interface RecordEffectivenessRequest {
  baby_id: string;
  track_id: string;
  was_effective: boolean;
  calming_time_seconds: number;
  context: 'crying' | 'fussy' | 'sleepy';
  emergency_mode?: boolean;
}

export interface RecordEmergencyRequest {
  baby_id: string;
  started_at: string;
  ended_at?: string;
  phases_completed: string[];
  was_successful?: boolean;
  tracks_used: string[];
}
