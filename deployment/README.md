# SLSL Dictionary: Deployment

## Deploy
Login with the gcloud CLI:
```
gcloud auth login --update-adc;
gcloud auth application-default login;
gcloud auth application-default set-quota-project slsl-dictionary;
gcloud config set project slsl-dictionary;
```

Deploy like this:
```
pulumi up --yes --refresh
```

The DB name can be found here: https://console.cloud.google.com/sql/instances/slsl-db-instance-04a74a9/databases?project=slsl-dictionary. Some other secrets intrinsic to GH Actions can be found in Bitwarden. The rest of the secrets can be found with `pulumi config get sql_user` and the like.

Note that sometimes deployment will fail due to this issue: https://github.com/banool/slsl_dictionary/issues/2. Just try again and it fixes it usually...

## Dump generation
`dump/dump.json` (the app's data) is produced by the `slsl-dump` Cloudflare cron worker in the `dictionary_backend` repo (`dump_worker/`): every 30 minutes it fetches this admin site's `/dump` endpoint and writes the result into the R2 media mirror.

The worker authenticates to `/dump` with a bearer token that this admin site validates (the `dump_auth_token` secret — see `slsl_backend/views.py`). Retrieve the value with:
```
pulumi config get dump_auth_token
```
The dump refreshes automatically on the cron; to force a refresh manually see "Dump worker" in `dictionary_backend/MANUAL_SETUP.md`.

## Domains
DNS for srilankansignlanguage.org is on Cloudflare. `admin.srilankansignlanguage.org` points at the admin Cloud Run service (the domain mapping in `lb.ts`). `cdn.srilankansignlanguage.org` is an R2 custom domain serving the media mirror — it is wired by `bun scripts/cf.ts r2 --project slsl` in the `dictionary_backend` repo, not from here.
