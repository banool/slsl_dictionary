import * as gcp from "@pulumi/gcp";
import { LOCATION } from "./common";
import { func } from "./functions";
import { appServiceAccount, role4 } from "./iam";

// Create a Cloud Scheduler job to call the DB dump function every 5 minutes.
const job = new gcp.cloudscheduler.Job(
  "job",
  {
    region: LOCATION,
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
    schedule: "*/5 * * * *",
    timeZone: "Europe/London",
  },
  { dependsOn: [role4] }
);