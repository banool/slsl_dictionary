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
export const database = new gcp.sql.Database("slsl-db", {
  instance: instance.name,
});

// Create a user in the DB.
const dbUserName = config.requireSecret("sql_user");
const dbUserPassword = config.requireSecret("sql_password");

export const dbUser = new gcp.sql.User("slsl-db-user", {
  instance: instance.name,
  name: dbUserName,
  password: dbUserPassword,
});
