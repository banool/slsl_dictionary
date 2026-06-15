# Site

The static info site for the app — landing page, privacy policy, and terms of service — served at https://landing.srilankansignlanguage.org. The apex `srilankansignlanguage.org` is already taken by the wider organisation's site, so this Auslan-style landing page lives at the `landing.` subdomain. The deployable content is the `src/` tree as-is; there is no build step.

It's a Cloudflare Pages project named `slsl-landing`. There are two moving parts, each a single command, both run from this directory (`site/`).

## Deploy the site

```sh
npx wrangler@latest pages deploy
```

The project name and output dir come from `wrangler.toml`, so no flags are needed. The first deploy creates the `slsl-landing` Pages project (wrangler prompts for the production branch — use `main`); later deploys ship a new version of it. CI (`.github/workflows/pages.yaml`) runs the same command on pushes to `main` that touch `site/**`.

## Wire up the domain

Domain reconciliation for this site lives in the private backend repo's consolidated Cloudflare CLI, so all the Cloudflare logic has one home. From a checkout of `dictionary_backend`:

```sh
bun scripts/cf.ts landing
```

It points `landing.srilankansignlanguage.org` at the `slsl-landing` Pages project: clears any stale DNS record, creates a proxied CNAME to the project's `*.pages.dev` target, and attaches the host as a Pages custom domain. Idempotent, so it's safe to re-run. **Run it once after the first deploy** (it needs the project to already exist); a redeploy never detaches an attached domain, so it isn't part of CI here.

## Credentials

The deploy command needs `CLOUDFLARE_API_TOKEN` (+ `CLOUDFLARE_ACCOUNT_ID`), stored as GitHub Actions secrets for CI. The `cf landing` domain step — run from the backend repo — needs a token with **Account → Cloudflare Pages: Edit**, **Zone → DNS: Edit**, and **Zone → Zone: Read**, scoped to `srilankansignlanguage.org`; see that repo's `MANUAL_SETUP.md`.

## Why a script for the domain?

Attaching a Pages custom domain isn't always enough on its own — if the zone already has a record for the hostname, that record keeps resolving until it's cleared, so the site can stay down. The `cf landing` command reconciles the DNS record and the custom-domain binding in one idempotent step, next to the shared-lists `api.*` / `share.*` reconciliation (`cf domains`) and the web app's `app.*` (`cf app --project slsl`) — every Cloudflare binding the account needs now lives in one typed CLI in the backend repo.
