import * as gcp from "@pulumi/gcp";
import * as pulumi from "@pulumi/pulumi";
import * as fs from "fs";
import { LOCATION, SLSL } from "./common";
import { envVars } from "./config";
import { database, dbUser } from "./db";
import { gcpServices } from "./project";
import { mediaBucket, staticBucket } from "./storage";
import { buildEnvObject } from "./utils";

const projectId = new pulumi.Config("gcp").require("project");

const GIT_SHA = "fd8d77041ad0638054d49791692b1f03f3ce246f";
const IMAGE_TAG = `sha-${GIT_SHA}`;

// todo idk if i need this
/*
const cloudRunServiceAccount = pulumi.interpolate`serviceAccount:service-${project.project.number}@serverless-robot-prod.iam.gserviceaccount.com`;
new gcp.projects.IAMMember(
  SLSL + "-can-use-serverless-vpc-connector",
  {
    member: cloudRunServiceAccount,
    project: getSharedVpcProject(),
    role: "roles/vpcaccess.user",
  },
  { dependsOn: [project.project] },
);
*/

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
          "run.googleapis.com/cpu-throttling": "false",
        },
      },
      spec: {
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
    dependsOn: [gcpServices.run, database, dbUser, mediaBucket, staticBucket],
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
