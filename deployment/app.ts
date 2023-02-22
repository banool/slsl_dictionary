import * as gcp from "@pulumi/gcp";
import * as pulumi from "@pulumi/pulumi";
import { LOCATION, SLSL } from "./common";
import { envVars } from "./config";
import { database, databaseInstance, databaseUser } from "./db";
import { gcpServices } from "./project";
import { mediaBucket, staticBucket } from "./storage";
import { appServiceAccount, role1, role2, role3, role4 } from "./iam";

const projectId = new pulumi.Config("gcp").require("project");

const GIT_SHA = "50bee2fc58c3d7504e3cf063db397bcaf07fb3a9";
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
          "autoscaling.knative.dev/maxScale": "5",
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
                cpu: "0.5",
                memory: "500Mi",
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
      mediaBucket,
      staticBucket,
      appServiceAccount,
      role1,
      role2,
      role3,
      role4,
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
