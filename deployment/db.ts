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
    // The live instance is on POSTGRES_18 (upgraded out-of-band); the old gcp
    // provider never diffed this, but gcp 9 does and would otherwise try to
    // "downgrade" to 14, which GCP rejects. Align the IaC with reality.
    databaseVersion: "POSTGRES_18",
    settings: {
      tier: "db-f1-micro",
      backupConfiguration: {
        // Daily automated backups (7 retained, the GCP default). This DB is the
        // hand-curated source of truth for all SLSL content; dump.json is a
        // derived copy that the dump cron would overwrite within 30 minutes of
        // the DB serving bad data, so it is not a substitute. PITR stays off —
        // daily granularity is enough and log archiving costs storage.
        enabled: true,
        // 17:00 UTC ≈ 03:00 Sydney, same overnight window as the local backup
        // jobs.
        startTime: "17:00",
      },
    },
    deletionProtection: true,
  },
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
