# Private Academy progress sync

A minimal Node 24 service for one learner's Apple devices. It stores progress and notes in SQLite on a persistent Railway volume. It has no broker credentials, trading functions, AI inference or dependency on the business app.

**Deployment status: owner instance deployed on Railway.** Health, authentication and service-restart persistence checks passed. Daily volume backups are enabled; a backup restore drill remains pending. Other users must deploy their own instance. Do not change workspace-wide spend settings: they may stop unrelated applications.

## Contract

- `GET /health`: public liveness only, no user data.
- `GET /v1/progress`: requires Bearer pairing key; returns `{revision,snapshot}`.
- `PUT /v1/progress`: requires the key and `{revision,snapshot}`. Atomic compare-and-swap; stale revision returns 409. Fetch, merge and retry.
- 5 MB request limit, 5,000 record limit, 20 KB per value; 120 authenticated requests/minute for the owner. No CORS is enabled.
- Snapshot format is compatible with saved-record exports from the Academy web app. This service does **not** accept web gateway identity headers or reuse website login.

Per-record merging happens on the native client: newer timestamps win, including undo markers. Empty records are not a supported way to delete all history from a client. Export/import backups are available. Use automatic device clocks. One key grants access to the complete single-owner dataset; do not share it publicly or run this as a multi-tenant service.

## Local verification

```sh
node --test test.mjs
```

The test uses a temporary database and loopback listener. It checks unauthenticated rejection, wrong-key rejection, saving, stale-write protection, malformed records and persistence across service restart.

## Railway deployment (after hosting approval)

Use a **new, separate project**, one service and one replica. Do not reuse a business service or database.

1. From this directory: `railway init --name kint10d-academy-sync`.
2. `railway add --service academy-sync`; link this directory to that service with `railway service link academy-sync`.
3. Attach a persistent volume mounted at `/data`: `railway volume add --mount-path /data`.
4. Generate a random 32-byte-or-longer private key locally. Keep the original in a password manager. Store only its SHA-256 hex digest as the service variable `ACADEMY_TOKEN_SHA256`; pass it through CLI stdin or the Railway secret variable editor. Never put the key in a Dockerfile, repository or command-line argument.
5. Set `DATABASE_PATH=/data/academy.sqlite`. The platform provides `PORT`.
6. Deploy only this directory: `railway up --path-as-root .`. Generate an HTTPS domain with `railway domain`.
7. Confirm `/health` is 200; unauthenticated `/v1/progress` is 401; pair a test device; verify a disposable record travels to a second device and survives a service restart.
8. Configure volume backups and a project/service cost budget using available Railway controls. Verify their scope before changing anything. Keep an offline exported snapshot too. Do not assume a low-memory app is free.
9. On each device enter the origin and original private key under Settings → Shared progress. The app rejects non-HTTPS endpoints and redirects, stores credentials in Keychain, and keeps local progress on errors.

Railway CLI syntax can vary by version; consult `--help`. Keep one replica with SQLite. Persistent volumes are required: a container filesystem alone is not durable. Deployments/restarts can interrupt sync briefly; the app preserves its local copy. Backups and end-to-end deployment recovery must be verified before calling hosting production-ready.

## Cost and security limitations

Railway bills usage. The owner instance uses an existing paid plan, with one replica, idle sleep and verified ceilings of 0.1 vCPU and 250 MB RAM. These resource ceilings are not an all-in monetary cap. Network, volume, backup usage and other projects still affect the workspace bill. If a per-project hard cap is unavailable, do not claim one or change an account-wide limit without approval. The service uses HTTPS transport; progress is plaintext to the application/database operator, not end-to-end encrypted. Local exports also contain plaintext notes. Pairing key rotation requires updating all devices; disconnecting a device locally does not revoke a copied key.

Sources: [pricing](https://docs.railway.com/pricing), [persistent volumes](https://docs.railway.com/volumes/reference), [cost controls](https://docs.railway.com/pricing/cost-control).
