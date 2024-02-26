import * as gcp from "@pulumi/gcp";
import * as pulumi from "@pulumi/pulumi";
import { ADMIN_LOCATION, SLSL } from "./common";
import { envVars } from "./admin-site-config";
import { database, databaseInstance, databaseUser } from "./db";
import { gcpServices } from "./project";
import { adminBucket } from "./storage";
import { appServiceAccount, role1, role2, role3 } from "./iam";

const projectId = new pulumi.Config("gcp").require("project");

const GIT_SHA = "73b6f5786f8466650f9d27f586b82377ae360e58";
const IMAGE_TAG = `sha-${GIT_SHA}`;

// TODO: Set up image retention policy.
const imageName = `banool/slsl-admin-site:${IMAGE_TAG}`;

const port = "8080";
const env = "prod";
const runArgs = [port, env];

export const adminSite = new gcp.cloudrun.Service(
  `${SLSL}-admin-site`,
  {
    name: `${SLSL}-admin-site`,
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
          "autoscaling.knative.dev/minScale": "0",
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
                cpu: "2",
                memory: "4Gi",
              },
              requests: {
                cpu: "0.1",
                memory: "128Mi",
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
  `${SLSL}-admin-site-public-access`,
  {
    member: "allUsers",
    role: "roles/run.invoker",
    service: adminSite.name,
    project: projectId,
    location: adminSite.location,
  },
  { dependsOn: [adminSite] }
);
