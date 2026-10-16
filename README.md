# Track Orders API (Neon + Deno Deploy)

Separate backend for the BRIDGE TV and RUSONG TV music request forms. The database connection is server-only. Never commit production secrets.

## API routes

- `GET /healthz` — basic health/configuration response.
- `POST /api/requests` — validated request; artist and direct YouTube/VK video link are required; new requests are always pending.
- `POST /api/catalog/search` — MusicBrainz by default; Discogs only if `DISCOGS_TOKEN` is configured.
- `GET /api/admin/requests?channel=btv|rtv|all&status=pending|approved|rejected|all` — validates a Supabase Auth access token and active channel grant.
- `POST /api/admin/requests/:uuid/review?channel=btv|rtv` — approve/reject pending requests.

The server derives the source channel from the allowlisted Origin, not from an anonymous request's claimed value. Admin routes validate access tokens against the existing channel-specific Supabase Auth project and check `track_request_admins` in Neon.

## Deploy on new Deno Deploy

1. Open https://console.deno.com/ and create a dynamic application from `btvrestored/track-orders-api`.
2. Select `main.ts` as the entrypoint.
3. Add environment variables in app settings:
   - `DATABASE_URL`: Neon pooled PostgreSQL URL; server-only.
   - `TRACK_REQUEST_HASH_SALT`: random value at least 24 characters.
   - `BTV_SUPABASE_URL` and `BTV_SUPABASE_PUBLISHABLE_KEY`: existing BTV Auth project values.
   - `RTV_SUPABASE_URL` and `RTV_SUPABASE_PUBLISHABLE_KEY`: existing RTV Auth project values.
   - `DISCOGS_TOKEN`: optional server-side token.
4. Deploy and open `/healthz`. It should report `ok: true` and `databaseConfigured: true`. This endpoint checks configuration, not DB reachability.
5. Copy the final Deno app URL. Put it in each site's `track-order-config.js` as `apiBaseUrl`, along with that site's existing Auth URL and publishable key. Never use a secret/service-role key in browser code.
6. Add moderator grants in Neon after checking the actual UUIDs in each existing Supabase project's Authentication → Users.

## Neon tables

`schema/001_track_orders.sql` creates:

- `track_requests`
- `track_request_admins`
- `track_request_rate_limits`
- `track_catalog_cache`
- `track_catalog_api_state`

This migration matches the tables created during the initial Neon setup. Review any existing data before applying it to a different project.

## Register moderators

Replace the placeholder UUIDs with actual Auth UIDs from Authentication → Users in the corresponding Supabase projects:

```sql
INSERT INTO public.track_request_admins (auth_project, auth_user_id, channel, active)
VALUES ('btv', 'BTV_AUTH_USER_UUID', 'btv', true)
ON CONFLICT (auth_project, auth_user_id, channel)
DO UPDATE SET active = EXCLUDED.active;

INSERT INTO public.track_request_admins (auth_project, auth_user_id, channel, active)
VALUES ('rtv', 'RTV_AUTH_USER_UUID', 'rtv', true)
ON CONFLICT (auth_project, auth_user_id, channel)
DO UPDATE SET active = EXCLUDED.active;

-- Optional: this BTV Auth user may moderate both channels.
-- INSERT INTO public.track_request_admins (auth_project, auth_user_id, channel, active)
-- VALUES ('btv', 'BTV_AUTH_USER_UUID', 'all', true);
```

The UUIDs above are placeholders. The same person may need one grant for the BTV Auth identity and another for the RTV Auth identity if both admin sites should work.

## Security

- `DATABASE_URL`, `TRACK_REQUEST_HASH_SALT`, and Discogs token are server-only.
- Only publishable Supabase keys are used to validate existing Auth tokens; no service-role key belongs in this repo or the frontend.
- The server validates request data, accepts only direct HTTPS YouTube/VK video links, and never auto-approves catalog matches.
- Limits are 5 submissions and 20 catalog searches per hashed identity/channel/10-minute bucket. Raw requester IPs are not stored. Proxy-header IP limits are best effort, not proof of identity.
- MusicBrainz calls include a User-Agent, a database-backed global throttle of at least 1.1 seconds, and a 12-hour cache. Respect MusicBrainz rate limits.
- Allowed production origins are `https://btvrestored.ru`, `https://www.btvrestored.ru`, `https://rtvrestored.ru`, and `https://www.rtvrestored.ru`. Update the allowlist only when production origins change.
