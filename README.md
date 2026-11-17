# auth

Central sign-in for the apps under `udin.web.id`, served at **auth.udin.web.id**. It runs
[authentik](https://goauthentik.io) as an OpenID Connect (OIDC) provider and identity broker:
apps trust this one provider, and this provider talks to Google (and later Facebook, GitHub and
others).

```
app (e.g. quranweb)  ->  auth.udin.web.id  ->  Google
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
tunnel) in front of it for `auth.udin.web.id` with TLS. First setup: open
`https://auth.udin.web.id/if/flow/initial-setup/` and create the admin account right away.

## Add Google as a login source

1. In Google Cloud Console create an OAuth client (type Web application). Authorized redirect
   URI: `https://auth.udin.web.id/source/oauth/callback/google/`.
2. In authentik: Directory, Federation and Social login, create a Google OAuth source with that
   client ID and secret, and use the slug `google`.
3. Add the source to the identification stage of the default authentication flow so the
   "Login with Google" button appears.

## Register an app (OIDC client)

For each app, create an OAuth2/OpenID provider and an application in authentik:

- Client type: confidential, with PKCE enabled.
- Redirect URI: exactly the app's callback URL (no wildcards), e.g.
  `https://quranweb.udin.web.id/api/auth/callback/authentik`.
- Scopes: `openid email profile`.
- Subject mode: hashed user ID (stable and not an email address).

The app then uses a standard OIDC library with the issuer
`https://auth.udin.web.id/application/o/<app-slug>/` (discovery document at
`.well-known/openid-configuration`). The app stores only the `sub` claim as the user key.

## Operations

- Back up the PostgreSQL volume and `data/` regularly, and keep a copy off the server.
- Upgrade one authentik release at a time (change `AUTHENTIK_TAG`), reading the release notes.
- If this provider is down, nobody can start a new sign-in. Apps keep their own sessions until
  they expire, so keep those sessions reasonably long.
