import * as pulumi from "@pulumi/pulumi";
import { buildEnvObject } from "./utils";
import { database, databaseInstance } from "./db";
import { adminBucket, mediaBucket } from "./storage";

// We start off with env vars that aren't secret / only known when we run `pulumi up`.
// We know the host / port for the DB ahead of time because we're using the CloudSQL
// proxy, which handles connecting to the actual DB.
const envRegular = [
  buildEnvObject("sql_engine", "django.db.backends.postgresql"),
  buildEnvObject("deployment_mode", "prod"),
  // Cloudflare R2 (media storage). Bucket name + account endpoint are not
  // secret; the access key id + secret are Pulumi secrets (SECRET_KEYS below).
  buildEnvObject("r2_bucket_name", "slsl-mirror"),
  buildEnvObject(
    "r2_endpoint_url",
    "https://47989fc190166b22bc15768dc41e8693.r2.cloudflarestorage.com",
  ),
];

const config = new pulumi.Config();

const SECRET_KEYS = [
  "secret_key",
  "sql_user",
  "sql_password",
  "admin_username",
  "admin_password",
  "admin_email",
  "additional_allowed_hosts",
  "dump_auth_token",
  "r2_access_key_id",
  "r2_secret_access_key",
];

// Add to that env objects where the value is a pulumi.Output containing a secret.
const envSecrets = SECRET_KEYS.map((key) =>
  buildEnvObject(key, config.requireSecret(key)),
);

// Add to that the random number. This is just used to force a redeploy if we want,
// since you can't just make cloud run services restart manually otherwise.
const randomNumber = 8;

const envRandom = [buildEnvObject("random_number", `${randomNumber}`)];

// Add the database name, which we only know after making the DB in db.ts
const envDbName = [buildEnvObject("sql_database", database.name)];

// Add an env var so the app knows what unix socket to use for connecting to the DB.
const envUnixSocket = [
  buildEnvObject(
    "sql_unix_socket",
    pulumi.interpolate`/cloudsql/${databaseInstance.connectionName}`,
  ),
];

// Add an env var for the bucket name.
const envAdminBucket = [buildEnvObject("admin_bucket_name", adminBucket.name)];
const envMediaBucket = [buildEnvObject("media_bucket_name", mediaBucket.name)];

// We use pulumi.all to combine all that into a single Output. Some values for keys in
// this output are themselves Outputs (the secrets).
var envVars = pulumi.all([
  ...envRegular,
  ...envSecrets,
  ...envRandom,
  ...envDbName,
  ...envUnixSocket,
  ...envAdminBucket,
  ...envMediaBucket,
]);

export { envVars };
