import * as pulumi from "@pulumi/pulumi";
import * as gcp from "@pulumi/gcp";

function enableGCPService(projectId: string, service: string) {
  return new gcp.projects.Service(`${service}.googleapis.com`, {
    service: `${service}.googleapis.com`,
    project: projectId,
    disableOnDestroy: false,
  });
}

export function enableGCPServices<ServiceKey extends string[]>(
  projectId: pulumi.Input<string>,
  ...services: ServiceKey
): { [K in ServiceKey[number]]: gcp.projects.Service } {
  return Object.fromEntries(
    services.map((svc) => [
      svc as any,
      pulumi
        .output(projectId)
        .apply((projectId) => enableGCPService(projectId, svc)),
    ])
  );
}

const projectId = new pulumi.Config("gcp").require("project");

export const gcpServices = enableGCPServices(
  projectId,
  "compute",
  "run",
  "cloudfunctions",
  "sqladmin"
);
