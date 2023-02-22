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

const GIT_SHA = "dd3aef1d8237314befece7656d14494236db00fd";

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

const imageName = `banool/slsl-backend:sha-${GIT_SHA}`;

// This is just used to force a redeploy if we want, since you can't just make
// cloud run services restart.
const randomNumber = fs.readFileSync(`${__dirname}/random_number.txt`, {
  encoding: "utf-8",
});

// Add the random number to the env vars.
envVars.apply((arr) => {
  [...arr, buildEnvObject("random_number", randomNumber)];
});

// Add the host for the DB.
envVars.apply((arr) => {
  [...arr, buildEnvObject("sql_host", "localhost")];
});

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
