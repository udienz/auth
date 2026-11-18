#!/usr/bin/env bash
# Runs on the server (piped over SSH by .github/workflows/deploy.yml):
#   bash -s -- <commit-sha> < scripts/deploy.sh
# The server keeps a checkout of this repository in AUTH_DIR (default /srv/auth) and a
# `.env` file created by hand (see README). Nothing secret is passed through this script.
set -euo pipefail

sha="${1:?usage: deploy.sh <commit-sha>}"
dir="${AUTH_DIR:-/srv/auth}"
keep_backups=7

[ -d "$dir/.git" ] || { echo "$dir is not a checkout of udienz/auth (see README)" >&2; exit 1; }
cd "$dir"
[ -f .env ] || { echo "$dir/.env is missing" >&2; exit 1; }

git fetch --quiet origin main
git merge-base --is-ancestor "$sha" origin/main || { echo "$sha is not on main" >&2; exit 1; }

# Dump the database before touching anything, so a bad upgrade can be undone.
if docker compose ps --status running --services 2>/dev/null | grep -qx postgresql; then
  mkdir -p backups
  # </dev/null: this script arrives on stdin (`bash -s`), and docker would swallow the rest of it.
  # shellcheck disable=SC2016  # variables are expanded inside the container
  docker compose exec -T postgresql sh -c 'pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB"' </dev/null \
    | gzip > "backups/pre-deploy-$(date -u +%Y%m%dT%H%M%SZ)-${sha:0:7}.sql.gz"
  # shellcheck disable=SC2012
  ls -1t backups/pre-deploy-*.sql.gz | tail -n +$((keep_backups + 1)) | xargs -r rm --
fi

git checkout --quiet --detach "$sha"
bash scripts/render-public.sh
docker compose pull --quiet
docker compose up -d --remove-orphans

echo "Waiting for authentik to become ready..."
for _ in $(seq 1 60); do
  if curl -fsS -o /dev/null http://127.0.0.1:9000/-/health/ready/; then
    echo "Deployed $sha"
    docker image prune -f >/dev/null
    exit 0
  fi
  sleep 5
done

echo "authentik did not become ready within 5 minutes; recent logs:" >&2
docker compose logs --tail=50 server worker >&2 || true
exit 1
