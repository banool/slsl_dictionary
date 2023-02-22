import * as gcp from "@pulumi/gcp";
import * as pulumi from "@pulumi/pulumi";
import { SLSL } from "./common";
import { mediaBucket, staticBucket } from "./storage";

const projectId = new pulumi.Config("gcp").require("project");

// Create a service account to use.
export const appServiceAccount = new gcp.serviceaccount.Account(
  SLSL + "-cloud-run-sa",
  {
    accountId: SLSL + "-cloud-run-sa",
    displayName: "SLSL Cloud Run Service Account",
    project: projectId,
  }
);
export const appServiceAccountRef = pulumi.interpolate`serviceAccount:${appServiceAccount.email}`;

// Grant it the necessary permissions.
export const role1 = new gcp.projects.IAMMember(
  SLSL + "-sa-run-invoker",
  {
    member: appServiceAccountRef,
    project: projectId,
    role: "roles/run.invoker",
  },
  { dependsOn: [appServiceAccount] }
);

export const role2 = new gcp.projects.IAMMember(
  SLSL + "-sa-cloudsql-client",
  {
    member: appServiceAccountRef,
    project: projectId,
    role: "roles/cloudsql.client",
  },
  { dependsOn: [appServiceAccount] }
);

export const role3 = new gcp.storage.BucketIAMMember(
  SLSL + "-sa-storage-object-admin-media",
  {
    member: appServiceAccountRef,
    bucket: mediaBucket.name,
    role: "roles/storage.objectAdmin",
  },
  { dependsOn: [appServiceAccount] }
);

export const role4 = new gcp.storage.BucketIAMMember(
  SLSL + "-sa-storage-object-admin-static",
  {
    member: appServiceAccountRef,
    bucket: staticBucket.name,
    role: "roles/storage.objectAdmin",
  },
  { dependsOn: [appServiceAccount] }
);