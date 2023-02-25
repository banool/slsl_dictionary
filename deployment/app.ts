import * as gcp from "@pulumi/gcp";
import * as pulumi from "@pulumi/pulumi";
import { LOCATION, SLSL } from "./common";
import { envVars } from "./config";
import { database, databaseInstance, databaseUser } from "./db";
import { gcpServices } from "./project";
import { mainBucket } from "./storage";
import { appServiceAccount, role1, role2, role3 } from "./iam";

const projectId = new pulumi.Config("gcp").require("project");

const GIT_SHA = "12ece30aac4e6a584a428e6bb4d13072db22df11";
const IMAGE_TAG = `sha-${GIT_SHA}`;

const imageName = `banool/slsl-backend:${IMAGE_TAG}`;

const port = "8080";
const env = "prod";
const runArgs = [port, env];

export const service = new gcp.cloudrun.Service(
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
    location: LOCATION,
    template: {
      metadata: {
        annotations: {
          "autoscaling.knative.dev/minScale": "1",
          "autoscaling.knative.dev/maxScale": "1",
          "run.googleapis.com/execution-environment": "gen2",
          // If this is true it makes sure we only get billed when handling a request,
          // though this means request handling will be take more time as the container
          // spins up.
          "run.googleapis.com/cpu-throttling": "false",
          // This configures the Cloud Run service to use the Cloud SQL proxy.
          "run.googleapis.com/cloudsql-instances":
            databaseInstance.connectionName,
        },
      },
      spec: {
        serviceAccountName: appServiceAccount.email,
        timeoutSeconds: 30,
        containerConcurrency: 10,
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
                cpu: "2",
                memory: "2Gi",
              },
              requests: {
                cpu: "1",
                memory: "750Mi",
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
      mainBucket,
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
    service: service.name,
    project: projectId,
    location: service.location,
  },
  { dependsOn: [service] }
);
