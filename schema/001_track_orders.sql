-- Neon PostgreSQL schema for Track Orders API.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS public.track_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  channel TEXT NOT NULL CHECK (channel IN ('btv', 'rtv')),
  artist TEXT NOT NULL CHECK (char_length(btrim(artist)) BETWEEN 1 AND 160),
  track_title TEXT CHECK (track_title IS NULL OR char_length(btrim(track_title)) <= 180),
  clip_url TEXT NOT NULL CHECK (char_length(clip_url) BETWEEN 12 AND 1000 AND clip_url LIKE 'https://%'),
  clip_provider TEXT NOT NULL CHECK (clip_provider IN ('youtube', 'vk')),
  catalog_provider TEXT CHECK (catalog_provider IS NULL OR catalog_provider IN ('musicbrainz', 'discogs')),
  catalog_match JSONB NOT NULL DEFAULT '{}'::jsonb,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  moderator_note TEXT CHECK (moderator_note IS NULL OR char_length(moderator_note) <= 1000),
  reviewed_by TEXT,
  reviewed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS track_requests_queue_idx ON public.track_requests (channel, status, created_at DESC);
CREATE INDEX IF NOT EXISTS track_requests_artist_idx ON public.track_requests (lower(artist));

CREATE TABLE IF NOT EXISTS public.track_request_admins (
  auth_project TEXT NOT NULL CHECK (auth_project IN ('btv', 'rtv')),
  auth_user_id UUID NOT NULL,
  channel TEXT NOT NULL CHECK (channel IN ('btv', 'rtv', 'all')),
  active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (auth_project, auth_user_id, channel)
);

CREATE TABLE IF NOT EXISTS public.track_request_rate_limits (
  key_hash CHAR(64) NOT NULL,
  action TEXT NOT NULL CHECK (action IN ('submit', 'catalog')),
  channel TEXT NOT NULL CHECK (channel IN ('btv', 'rtv')),
  bucket_start TIMESTAMPTZ NOT NULL,
  attempts INTEGER NOT NULL DEFAULT 0 CHECK (attempts >= 0),
  PRIMARY KEY (key_hash, action, channel, bucket_start)
);

CREATE TABLE IF NOT EXISTS public.track_catalog_cache (
  cache_key CHAR(64) PRIMARY KEY,
  provider TEXT NOT NULL CHECK (provider IN ('musicbrainz', 'discogs')),
  response JSONB NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.track_catalog_api_state (
  provider TEXT PRIMARY KEY CHECK (provider IN ('musicbrainz', 'discogs')),
  next_allowed_at TIMESTAMPTZ NOT NULL
);
COMMIT;
