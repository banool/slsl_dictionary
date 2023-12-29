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

## Cloud Function
To run the cloud function manually do this:
```
gcloud functions call --region us-east1 `pulumi stack output functionName`
```

You should see output like this:
```
executionId: 1h9fv0mejjid
result: Uploaded dump containing 1419 entries to slsl-main-bucket-f32e475
```

To deploy any changes to the cloud function (e.g. to main.py or requirements.txt) just run the above, it will zip it all up for you.

## Domains
You need to point admin.srilankasignlanguage.org and cdn.srilankansignlanguge.org to the Cloud Run and LB (in front of the bucket) IP addresses respectively from where we manage the DNS for the domain (currently Bluehost).
