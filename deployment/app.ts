import * as gcp from "@pulumi/gcp";
import * as pulumi from "@pulumi/pulumi";
import { ADMIN_LOCATION, SLSL } from "./common";
import { envVars } from "./config";
import { database, databaseInstance, databaseUser } from "./db";
import { gcpServices } from "./project";
import { adminBucket } from "./storage";
import { appServiceAccount, role1, role2, role3 } from "./iam";

const projectId = new pulumi.Config("gcp").require("project");

const GIT_SHA = "3e035d115d13f81a0ebae715fec1d37760d87664";
const IMAGE_TAG = `sha-${GIT_SHA}`;

const imageName = `banool/slsl-backend:${IMAGE_TAG}`;

const port = "8080";
const env = "prod";
const runArgs = [port, env];

export const adminService = new gcp.cloudrun.Service(
  SLSL,
  {
    name: SLSL,
    autogenerateRevisionName: true,
    metadata: {
      annotations: {
        "run.googleapis.com/launch-stage": "BETA",
      },
    },
    project: projectId,
    location: ADMIN_LOCATION,
    template: {
      metadata: {
        namespace: projectId,
        annotations: {
          "autoscaling.knative.dev/minScale": "1",
          "autoscaling.knative.dev/maxScale": "3",
          "run.googleapis.com/execution-environment": "gen2",
          // If this is true it makes sure we only get billed when handling a request,
          // though this means request handling will be take more time as the container
          // spins up.
          "run.googleapis.com/cpu-throttling": "true",
          // This configures the Cloud Run service to use the Cloud SQL proxy.
          "run.googleapis.com/cloudsql-instances":
            databaseInstance.connectionName,
        },
      },
      spec: {
        serviceAccountName: appServiceAccount.email,
        timeoutSeconds: 30,
        containerConcurrency: 50,
        containers: [
          {
            image: imageName,
            args: runArgs,
            envs: envVars,
            ports: [
              {
                name: "http1",
                containerPort: 8080,
              },
            ],
            resources: {
              limits: {
                cpu: "4",
                memory: "4Gi",
              },
              requests: {
                cpu: "1",
                memory: "1Gi",
              },
            },
          },
        ],
      },
    },
    traffics: [
      {
        latestRevision: true,
        percent: 100,
      },
    ],
  },
  {
    dependsOn: [
      gcpServices.run,
      database,
      databaseUser,
      adminBucket,
      appServiceAccount,
      role1,
      role2,
      role3,
    ],
    customTimeouts: {
      create: "5m",
      update: "3m",
      delete: "5m",
    },
    ignoreChanges: [
      'metadata.annotations["run.googleapis.com/client-name"]',
      'template.metadata.annotations["run.googleapis.com/client-name"]',
    ],
  }
);

// Make service accessible to the public internet.
new gcp.cloudrun.IamMember(
  "public-access",
  {
    member: "allUsers",
    role: "roles/run.invoker",
    service: adminService.name,
    project: projectId,
    location: adminService.location,
  },
  { dependsOn: [adminService] }
);
