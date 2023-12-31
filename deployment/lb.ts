import * as gcp from "@pulumi/gcp";
import * as pulumi from "@pulumi/pulumi";
import { adminSite } from "./admin-site-cloud-run";
import { ADMIN_LOCATION, SITE } from "./common";

const projectId = new pulumi.Config("gcp").require("project");

// Rather than using the usual LB + static IP approach we're using custom domain mapping.
// https://cloud.google.com/run/docs/mapping-custom-domains#run
// https://www.pulumi.com/registry/packages/gcp/api-docs/cloudrun/domainmapping/
new gcp.cloudrun.DomainMapping("slsl-admin-domain-mapping", {
  location: ADMIN_LOCATION,
  metadata: {
    namespace: projectId,
  },
  spec: {
    routeName: adminSite.name,
  },
  name: `admin.${SITE}`,
});
