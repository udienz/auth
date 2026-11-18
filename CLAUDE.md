# auth

Central sign-in provider for `udienz.web.id` apps (auth.udienz.web.id). Runs authentik via Docker
Compose; this repo is configuration and docs only, no application code.

- Language: all files, commit messages and PRs in English.
- Never commit secrets. `.env`, `data/`, `certs/` and `backups/` are git-ignored; document new
  variables in `.env.example` with an empty value.
- `docker-compose.yml` is derived from the official authentik file with deliberate hardening
  (localhost-only port, no Docker socket, no root worker). Keep those changes when upgrading;
  diff against `https://goauthentik.io/docker-compose.yml` for each new version.
- Pin `AUTHENTIK_TAG` to an exact release. Upgrade one release at a time.
- Validate config changes with `PG_PASS=x AUTHENTIK_SECRET_KEY=y docker compose config -q`
  (needs an `.env` file to exist; copy `.env.example`).
- Registered apps are listed in the README (slug, redirect URIs). Update that table in the same
  PR whenever an app or redirect URI changes in authentik, since authentik config is not in git.
- CI and deploy: `ci.yml`; `deploy.yml` (tag `v*`, only from `main`, Environment `production`).
  Server logic lives in `scripts/deploy.sh`; keep it shellcheck-clean. The server owns `.env`;
  GitHub holds only SSH secrets (repository level). One instance serves both `auth` and
  `auth-qa` hostnames; there is deliberately no second stack (RAM).
