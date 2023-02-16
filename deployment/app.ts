import * as gcp from "@pulumi/gcp";
import * as pulumi from "@pulumi/pulumi";
import * as fs from "fs";
import { SLSL } from "./common";
import * as url from "url";

const project = new pulumi.Config("gcp").require("project");

const GIT_SHA = "8a9ac076c34efc851957d39ae2a8d2fda16111c5";

const cloudRunServiceAccount = pulumi.interpolate`serviceAccount:service-${project.project.number}@serverless-robot-prod.iam.gserviceaccount.com`;

new gcp.artifactregistry.RepositoryIamMember(
  SLSL + "-pull-from-global-docker-repo",
  {
    repository: "aptos-internal",
    member: cloudRunServiceAccount,
    role: "roles/artifactregistry.reader",
    project: GLOBAL_GCP_PROJECT,
    location: US_WEST1,
  },
  { dependsOn: [project.project] },
);

new gcp.projects.IAMMember(
  SLSL + "-can-use-serverless-vpc-connector",
  {
    member: cloudRunServiceAccount,
    project: getSharedVpcProject(),
    role: "roles/vpcaccess.user",
  },
  { dependsOn: [project.project] },
);

const imageNameInGCP = pulumi.interpolate`${getDockerRepoInternal()}/node-checker:${GIT_SHA}`;

// Map of config name to root key secret name if necessary.
// For a config to be included in the deployment, it must be listed here.
const configs = new Map<string, string | null>([
  ["devnet_fullnode", null],
  ["testnet_fullnode", null],
  ["mainnet_fullnode", null],
]);

// Map of config name to config content.
const configContent = new Map(
  Array.from(configs, ([key, _value]) => [
    key,
    fs.readFileSync(`${__dirname}/configs/${key}.yaml`, { encoding: "utf-8" }),
  ]),
);

// This is just used to force a redpeploy if we want, since you can't just make
// cloud run services restart.
const randomNumber = fs.readFileSync(`${__dirname}/random_number.txt`, { encoding: "utf-8" });

const inContainerConfigsDir = "/configs";

// Build the run command.
var runCommand = "mkdir -p /configs && ";
for (const [key, value] of configs) {
  runCommand += `printf "$${key}" > ${inContainerConfigsDir}/${key}.yaml && `;
  if (value != null) {
    runCommand += `sed -i -e "s/REPLACE_ME_WITH_MINT_KEY/$${value}/g" ${key}.yaml && `;
  }
}
runCommand += `/usr/local/bin/aptos-node-checker server run --baseline-config-paths ${inContainerConfigsDir}/* --listen-address 0.0.0.0 --listen-port 8080`;

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
    project: project.projectId,
    location: US_WEST1,
    template: {
      metadata: {
        annotations: {
          "autoscaling.knative.dev/minScale": "1",
          "autoscaling.knative.dev/maxScale": "50",
          "run.googleapis.com/execution-environment": "gen2",
          "run.googleapis.com/cpu-throttling": "false",
          // Access to private IPs should go through Serverless VPC connector
        },
      },
      spec: {
        serviceAccountName: appServiceAccount.email,
        timeoutSeconds: 45,
        containerConcurrency: 50,
        containers: [
          {
            image: imageNameInGCP,
            commands: ["/bin/bash"],
            args: ["-c", runCommand],
            envs: [
              ...envFromMap({
                RUST_LOG: "info",
                RUST_BACKTRACE: "0",
                RANDOM_NUMBER: `"${randomNumber}"`,
              }),
              ...envFromMap(Object.fromEntries(configContent)),
              ...secretEnvVarRefs,
            ],
            ports: [
              {
                name: "http1",
                containerPort: 8080,
              },
            ],
            resources: {
              limits: {
                cpu: "8",
                memory: "32Gi",
              },
              requests: {
                cpu: "8",
                memory: "32Gi",
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
