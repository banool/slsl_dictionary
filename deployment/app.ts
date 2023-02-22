import * as gcp from "@pulumi/gcp";
import * as pulumi from "@pulumi/pulumi";
import * as fs from "fs";
import { LOCATION, SLSL } from "./common";
import { envVars } from "./config";

const project = new pulumi.Config("gcp").require("project");

const GIT_SHA = "8a9ac076c34efc851957d39ae2a8d2fda16111c5";

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

// todo update this with the full github path.
// though first investigate if there are any costs to pulling the image from outside
const imageName = pulumi.interpolate`${getDockerRepoInternal()}/node-checker:${GIT_SHA}`;

// This is just used to force a redeploy if we want, since you can't just make
// cloud run services restart.
const randomNumber = fs.readFileSync(`${__dirname}/random_number.txt`, { encoding: "utf-8" });

const port = "8000";
const env = "prod";
const runArgs = [port, env];

export const service = new gcp.cloudrun.Service(
  SLSL,
  {
    name: SLSL,
    autogenerateRevisionName: true,
    metadata: {
      annotations: {
        // "run.googleapis.com/ingress": "internal-and-cloud-load-balancing",
        "run.googleapis.com/launch-stage": "BETA",
      },
    },
    project: project,
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
    dependsOn: [gcpServices.run, project],
    customTimeouts: {
      create: "5m",
      update: "3m",
      delete: "5m",
    },
    ignoreChanges: [
      // "template.spec.containers[0].image",
      'metadata.annotations["run.googleapis.com/client-name"]',
      'template.metadata.annotations["run.googleapis.com/client-name"]',
    ],
  },
);

// make service accessible accessible from GCP Cloud Load Balancing
new gcp.cloudrun.IamMember(
  "public-access",
  {
    member: "allUsers",
    role: "roles/run.invoker",
    service: service.name,
    project: project.projectId,
    location: service.location,
  },
  { dependsOn: [project.project] },
);
