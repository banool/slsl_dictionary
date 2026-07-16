import * as gcp from "@pulumi/gcp";
import * as pulumi from "@pulumi/pulumi";
import { ADMIN_LOCATION, SLSL } from "./common";
import { envVars } from "./admin-site-config";
import { database, databaseInstance, databaseUser } from "./db";
import { gcpServices } from "./project";
import { adminBucket } from "./storage";
import { appServiceAccount, role1, role2, role3 } from "./iam";

const projectId = new pulumi.Config("gcp").require("project");

const GIT_SHA = "018de512999f8fd5249df47d14e5c47b90ee15ed";
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
          // The admin image is slow to import (~3 min) when the container only
          // has its requested 0.1 vCPU during startup, which blew the Cloud Run
          // startup window and made cold starts fail. Startup CPU boost gives
          // full CPU during startup *only* (not always-on, so billing is
          // unaffected outside startup), letting the container bind the port in
          // time.
          "run.googleapis.com/startup-cpu-boost": "true",
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
      create: "8m",
      // Bumped from 3m: a cold start (image import + migrate) can take a few
      // minutes, and the provider was giving up before the new revision went
      // healthy. Startup CPU boost (above) should keep this well under, but the
      // extra headroom avoids a premature timeout reporting a false failure.
      update: "8m",
      delete: "5m",
    },
    ignoreChanges: [
      'metadata.annotations["run.googleapis.com/client-name"]',
      'template.metadata.annotations["run.googleapis.com/client-name"]',
    ],
  },
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
  { dependsOn: [adminSite] },
);
