# auth

Central sign-in for the apps under `udienz.web.id`, served at **auth.udienz.web.id**. It runs
[authentik](https://goauthentik.io) as an OpenID Connect (OIDC) provider and identity broker:
apps trust this one provider, and this provider talks to Google (and later Facebook, GitHub and
others).

```
app (e.g. quranweb)  ->  auth.udienz.web.id  ->  Google
                     <-  authorization code <-  callback
app exchanges the code for an ID token, then keeps its own session
```

This repository holds only deployment config and documentation. No secrets are committed.

## Run

```bash
cp .env.example .env            # then fill in PG_PASS and AUTHENTIK_SECRET_KEY
docker compose up -d
```

authentik listens on `127.0.0.1:9000` only. Put a reverse proxy (nginx, Caddy or a Cloudflare
tunnel) in front of it for `auth.udienz.web.id` with TLS. An nginx example (with WebSocket
support and the certbot steps) is in `deploy/nginx-auth.conf.example`. First setup: open
`https://auth.udienz.web.id/if/flow/initial-setup/` and create the admin account right away.

## Deploy (GitHub Actions)

- **CI** (`ci.yml`, every push to `main` and every PR): validates `docker-compose.yml`, checks that
  the hardening in `CLAUDE.md` is still there, runs shellcheck, and refuses tracked secrets.
- **Deploy** (`deploy.yml`): pushing a `v*` tag runs `scripts/deploy.sh` on the server over SSH.
  Only commits on `main` can be released. Roll back by running the workflow for an older tag.

```bash
git tag -a v1.0.0 -m "First release" && git push origin v1.0.0
```

There is one authentik instance (`/srv/auth`, port 9000) and no separate QA stack: a second one
costs about 1.3 GB of RAM, which the server cannot spare. The hostnames `auth.udienz.web.id` and
`auth-qa.udienz.web.id` both reach it. Apps register one OIDC application per environment
(for example quranweb and quranweb-qa), and a Brand per hostname (Customization, Brands) can give
each its own look. This is not isolation: both hostnames see the same users and configuration.
Test upgrades on a temporary second stack, and read the release notes first.

One-time server setup: clone this repository to `/srv/auth`, create `.env` there from
`.env.example`, and add the deploy public key to the SSH user's `authorized_keys`. In GitHub the
repository secrets are `AUTH_SSH_PRIVATE_KEY`, `AUTH_SSH_KNOWN_HOSTS`, `AUTH_SSH_HOST`,
`AUTH_SSH_PORT` and `AUTH_SSH_USER`. The script dumps the database to `backups/` first (last 7
kept), pulls the pinned image, restarts the stack and waits for `/-/health/ready/`.

## Add Google as a login source

1. In Google Cloud Console create an OAuth client (type Web application). Authorized redirect
   URI: `https://auth.udienz.web.id/source/oauth/callback/google/`.
2. In authentik: Directory, Federation and Social login, create a Google OAuth source with that
   client ID and secret, and use the slug `google`.
3. Add the source to the identification stage of the default authentication flow so the
   "Login with Google" button appears.

## Register an app (OIDC client)

For each app, create an OAuth2/OpenID provider and an application in authentik:

- Client type: confidential, with PKCE enabled.
- Redirect URI: exactly the app's callback URL (no wildcards), e.g.
  `https://quranweb.udienz.web.id/api/auth/callback/authentik`.
- Scopes: `openid email profile`.
- Subject mode: hashed user ID (stable and not an email address).

The app then uses a standard OIDC library with the issuer
`https://auth.udienz.web.id/application/o/<app-slug>/` (discovery document at
`.well-known/openid-configuration`). The app stores only the `sub` claim as the user key.

### Registered apps

| Application | Slug | Redirect URIs | Notes |
|---|---|---|---|
| Quranweb (production) | `quranweb` | `https://quranweb.udienz.web.id/api/auth/callback/authentik` | Path is provisional until quranweb picks its OIDC library. |
| Quranweb QA | `quranweb-qa` | `https://quranweb-qa.udienz.web.id/api/auth/callback/authentik`, `http://localhost:3000/api/auth/callback/authentik` | The localhost URI is for local development and exists only on this app. |

Both use implicit consent, a confidential client, the self-signed signing key (RS256) and the
scopes `openid email profile`. Clients must use PKCE with `S256`. Client secrets live only in
each app's server environment, never in git. Update this table whenever an app or redirect URI
changes.

### Sign-in sources and account types

Google (slug `google`) is the only source. Its user matching mode is "Link users on unique
identifier", so a Google login never merges into an existing local account, even with the same
email. People who sign in through a source are `external` users: they can sign in to apps but
cannot open the authentik interface. The only admin is the local `akadmin`-style account with
a strong password and MFA. The Google OAuth app is in Testing mode (test users only) until
the privacy policy page of the first app exists.

## Operations

- Back up the PostgreSQL volume and `data/` regularly, and keep a copy off the server.
- Upgrade one authentik release at a time (change `AUTHENTIK_TAG`), reading the release notes.
- If this provider is down, nobody can start a new sign-in. Apps keep their own sessions until
  they expire, so keep those sessions reasonably long.
