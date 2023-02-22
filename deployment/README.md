# SLSL Dictionary: Deployment

To connect to the DB directly from your local machine run a Cloud SQL Proxy:
```
cloud-sql-proxy slsl-dictionary:asia-south1:slsl-db-instance-04a74a9 --port 5433
```

Then connect with your postgres client of choice. The DB name can be found here: https://console.cloud.google.com/sql/instances/slsl-db-instance-04a74a9/databases?project=slsl-dictionary. The rest of the secrets can be found with `pulumi config get sql_user` and the like.
