import * as pulumi from "@pulumi/pulumi";
import { buildEnvObject } from "./utils";
import * as fs from "fs";

// We start off with env vars that aren't secret / only known when we run `pulumi up`.
// We know the host / port for the DB ahead of time because we're using the CloudSQL
// proxy, which handles connecting to the actual DB.
const envRegular = [
  buildEnvObject("sql_engine", "django.db.backends.postgresql"),
  buildEnvObject("sql_database", "slsl"),
  buildEnvObject("sql_host", "127.0.0.1"),
  buildEnvObject("sql_port", "5432"),
  buildEnvObject("deployment_mode", "prod"),
  // Remove these:
  buildEnvObject("media_bucket", "todo"),
  buildEnvObject("static_bucket", "todo"),
];

const config = new pulumi.Config();

const SECRET_KEYS = [
  "secret_key",
  "sql_user",
  "sql_password",
  "admin_username",
  "admin_password",
  "admin_email",
];

// Add to that env objects where the value is a pulumi.Output containing a secret.
const envSecrets = SECRET_KEYS.map((key) => buildEnvObject(key, config.requireSecret(key)));

// Add to that the random number. This is just used to force a redeploy if we want,
// since you can't just make cloud run services restart manually otherwise.
const randomNumber = fs.readFileSync(`${__dirname}/random_number.txt`, {
  encoding: "utf-8",
});

const envRandom = [buildEnvObject("random_number", randomNumber)];

// We use pulumi.all to combine all that into a single Output. Some values for keys in
// this output are themselves Outputs (the secrets).
var envVars = pulumi.all([...envRegular, ...envSecrets, ...envRandom]);

export { envVars };
