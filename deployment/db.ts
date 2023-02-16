import * as pulumi from "@pulumi/pulumi";
import * as gcp from "@pulumi/gcp";
import { LOCATION } from "./common";

const config = new pulumi.Config();

// Create a cloud SQL instance.
const instance = new gcp.sql.DatabaseInstance("slsl-db-instance", {
    region: LOCATION,
    databaseVersion: "POSTGRES_14",
    settings: {
        tier: "db-f1-micro",
    },
    deletionProtection: true,
});

// Create a DB in that instance.
const database = new gcp.sql.Database("slsl-db", {instance: instance.name});

// Create a user in the DB.
const dbUserName = config.require("db-user-name");
const dbUserPassword = config.requireSecret("db-user-password");

const dbUser = new gcp.sql.User(
    "slsl-db-user",
    {
        instance: instance.name,
        name: dbUserName,
        password: dbUserPassword,
    }
)
