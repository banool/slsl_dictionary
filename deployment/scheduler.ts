import * as gcp from "@pulumi/gcp";
import { ADMIN_LOCATION, RUN_EVERY_N_MINUTES, SLSL } from "./common";
import { func } from "./functions";
import { appServiceAccount, role4 } from "./iam";

// Create a Cloud Scheduler job to call the DB dump function every 5 minutes.
new gcp.cloudscheduler.Job(
  `${SLSL}-dump-job`,
  {
    region: ADMIN_LOCATION,
    httpTarget: {
      httpMethod: "GET",
      uri: func.httpsTriggerUrl,
      oidcToken: {
        serviceAccountEmail: appServiceAccount.email,
      },
    },
    attemptDeadline: "60s",
    description: "Scheduled call of DB dump cloud function",
    retryConfig: {
      maxDoublings: 2,
      maxRetryDuration: "10s",
      minBackoffDuration: "1s",
      retryCount: 3,
    },
    schedule: `*/${RUN_EVERY_N_MINUTES} * * * *`,
    timeZone: "Europe/London",
  },
  { dependsOn: [role4] }
);
