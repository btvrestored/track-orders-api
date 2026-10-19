# Track Orders API (Neon + Render)

Separate API for BTV and RTV music request forms, backed by the existing Neon PostgreSQL database. The Render deployment uses the Dockerfile in this repository. Never commit production secrets.

## API routes

- `GET /healthz` — checks database connectivity, required tables and environment configuration.
- `POST /api/requests` — validates and stores public requests as `pending`.
- `POST /api/catalog/search` — MusicBrainz by default; Discogs if `DISCOGS_TOKEN` is configured.
- `GET /api/admin/requests?channel=btv|rtv|all&status=pending|approved|rejected|all` — validates an existing Supabase Auth token and channel grant.
- `POST /api/admin/requests/:uuid/review?channel=btv|rtv` — approves or rejects a pending request.

The public API derives the channel from the allowlisted website Origin. Moderator access is checked server-side against the matching existing BTV or RTV Supabase Auth project and the `track_request_admins` table in Neon.

## Deploy to Render

### Recommended: use the Blueprint

1. Open https://dashboard.render.com/ and connect the GitHub account if needed.
2. Choose **New → Blueprint**.
3. Select `btvrestored/track-orders-api` and branch `feat/render-hosting-2026-10-19`.
4. Render should detect `render.yaml`. Review the service and keep the compute plan at **Free** for the initial test.
5. Fill the environment variables in Render's setup flow or open the service's **Environment** page after creation.
6. Deploy and wait for the build to finish.

If Blueprint setup is unavailable, use **New → Web Service**, select the same repository and branch, choose **Docker** as the runtime, and use `./Dockerfile` as the Dockerfile path. Set health check path to `/healthz`.

### Required environment variables

Use the same actual values as the currently working Deno Deploy configuration:

- `DATABASE_URL` — Neon pooled PostgreSQL connection string. Server-only.
- `TRACK_REQUEST_HASH_SALT` — your existing random secret, at least 24 characters.
- `BTV_SUPABASE_URL` — existing BTV Supabase project URL.
- `BTV_SUPABASE_PUBLISHABLE_KEY` — existing public/publishable key for BTV Auth.
- `RTV_SUPABASE_URL` — existing RTV Supabase project URL.
- `RTV_SUPABASE_PUBLISHABLE_KEY` — existing public/publishable key for RTV Auth.
- `DISCOGS_TOKEN` — optional; leave empty or unset unless Discogs search is enabled.

Do not store `DATABASE_URL`, the hash salt, or a Discogs token in GitHub, public JavaScript, a Docker image, or chat. `.env.example` contains only placeholders.

### Verify before switching the websites

1. Open `https://YOUR-RENDER-SERVICE.onrender.com/healthz`. It should return HTTP 200 with `ok: true`, `databaseConnected: true`, `schemaReady: true`, `missingTables: []`, `rateLimitSaltConfigured: true`, `btvAuthConfigured: true`, and `rtvAuthConfigured: true`.
2. Search MusicBrainz from the BTV test form and check that results render.
3. Submit exactly one test request from a website with the correct Origin. Confirm it exists in Neon with status `pending`.
4. Sign in to the relevant existing Auth account, verify the correct admin UID grant in Neon, and test approving/rejecting the request.
5. Only after those tests pass, change `apiBaseUrl` in the BTV and RTV website configs to the Render URL and deploy those site branches.

Keep the old Deno URL saved until Render passes all tests. Do not remove or migrate Neon data as part of this hosting move.

## Free-plan caveats

Render Free web services spin down after 15 minutes without inbound traffic and may take about a minute to start on the next request. The free tier also has workspace-level limits (including 750 instance hours per calendar month and outbound bandwidth/build-pipeline allowances). It is suitable for testing/hobby use, not a guarantee of uninterrupted production operation. Check current usage in Render Dashboard.

## Database and permissions

The Neon schema must already include these tables:

- `track_requests`
- `track_request_admins`
- `track_request_rate_limits`
- `track_catalog_cache`
- `track_catalog_api_state`

Do not rerun schema creation against the live database without first checking whether the tables already exist. This API connects using `DATABASE_URL`; browsers never connect directly to Neon.

## Security

- Requests require an artist and a direct HTTPS YouTube/VK video URL. New requests always start as `pending`.
- Rate limiting is 5 submissions and 20 catalogue searches per hashed identity/channel/10-minute bucket. Raw IP addresses are not persisted.
- MusicBrainz calls include a User-Agent, a shared database-backed throttle of at least 1.1 seconds, and a 12-hour cache. Respect its rate limit.
- Catalog matches are metadata evidence only and never auto-approve a music request.
- Current allowed production Origins: `https://btvrestored.ru`, `https://www.btvrestored.ru`, `https://rtvrestored.ru`, and `https://www.rtvrestored.ru`.
