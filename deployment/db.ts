import * as pulumi from "@pulumi/pulumi";
import * as gcp from "@pulumi/gcp";
import { LOCATION } from "./common";

const config = new pulumi.Config();
const projectId = new pulumi.Config("gcp").require("project");

// Create a cloud SQL instance.
export const databaseInstance = new gcp.sql.DatabaseInstance(
  "slsl-db-instance",
  {
    region: LOCATION,
    databaseVersion: "POSTGRES_14",
    settings: {
      tier: "db-f1-micro",
      /*
      ipConfiguration: {
        ipv4Enabled: false,
        privateNetwork: pulumi.interpolate`projects/${projectId}/global/networks/default`,
      }
      */
    },
    deletionProtection: true,
  }
);

// Create a DB in that instance.
export const database = new gcp.sql.Database("slsl-db", {
  instance: databaseInstance.name,
});

// Create a user in the DB.
const dbUserName = config.requireSecret("sql_user");
const dbUserPassword = config.requireSecret("sql_password");

export const databaseUser = new gcp.sql.User("slsl-db-user", {
  instance: databaseInstance.name,
  name: dbUserName,
  password: dbUserPassword,
});
