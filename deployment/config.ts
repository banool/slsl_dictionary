import * as pulumi from "@pulumi/pulumi";

// We start off with env vars that aren't secret / only known when we run `pulumi up`.
export var envVars = pulumi.output([
    buildEnvObject("sql_engine", "django.db.backends.postgres"),
    buildEnvObject("sql_database", "slsl"),
    buildEnvObject("deployment_mode", "prod"),
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

for (var secretKey of SECRET_KEYS) {
    envVars.apply(arr => {
        [...arr, buildEnvObject(secretKey, config.requireSecret(secretKey))]
    });
}

function buildEnvObject(name: string, value: string | pulumi.Output<string>) {
    if (typeof value == "string") {
        value = pulumi.output(value);
    }
    return {name: name, value: value};
}
