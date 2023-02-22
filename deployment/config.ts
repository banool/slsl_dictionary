import * as pulumi from "@pulumi/pulumi";
import { buildEnvObject } from "./utils";

// We start off with env vars that aren't secret / only known when we run `pulumi up`.
// We know the host / port for the DB ahead of time because we're using the CloudSQL
// proxy, which handles connecting to the actual DB.
export var envVars = pulumi.output([
  buildEnvObject("sql_engine", "django.db.backends.postgres"),
  buildEnvObject("sql_database", "slsl"),
  buildEnvObject("sql_host", "127.0.0.1"),
  buildEnvObject("sql_port", "5432"),
  buildEnvObject("deployment_mode", "prod"),
  // Remove these:
  buildEnvObject("media_bucket", "todo"),
  buildEnvObject("static_bucket", "todo"),
]);

const SECRET_KEYS = [
  "secret_key",
  "sql_user",
  "sql_password",
  "admin_username",
  "admin_password",
  "admin_email",
];

const config = new pulumi.Config();

// Here we add the secrets from Pulumi to the env vars. After this, all we need are the
// env vars that we determine from other infra pieces, like the DB, buckets, etc. We do
// that in app.ts.
for (var secretKey of SECRET_KEYS) {
  envVars.apply((arr) => {
    [...arr, buildEnvObject(secretKey, config.requireSecret(secretKey))];
  });
}
