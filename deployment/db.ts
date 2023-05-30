import * as pulumi from "@pulumi/pulumi";
import * as gcp from "@pulumi/gcp";
import { ADMIN_LOCATION } from "./common";

const config = new pulumi.Config();

// Create a user in the DB.
const dbUserName = config.requireSecret("sql_user");
const dbUserPassword = config.requireSecret("sql_password");

// Create a cloud SQL instance.
export const databaseInstance = new gcp.sql.DatabaseInstance(
  "slsl-admin-db-instance",
  {
    region: ADMIN_LOCATION,
    databaseVersion: "POSTGRES_14",
    settings: {
      tier: "db-f1-micro",
    },
    deletionProtection: true,
  }
);

// Create a DB in that instance.
export const database = new gcp.sql.Database("slsl-admin-db", {
  instance: databaseInstance.name,
});

export const databaseUser = new gcp.sql.User("slsl-admin-db-user", {
  instance: databaseInstance.name,
  name: dbUserName,
  password: dbUserPassword,
});
