import * as gcp from "@pulumi/gcp";
import * as pulumi from "@pulumi/pulumi";
import { service } from "./app";
import { LOCATION, SLSL } from "./common";

const config = new pulumi.Config();

// Reserve a static IP
export const staticIp = new gcp.compute.GlobalAddress(
  `${SLSL}-global-address`,
  {
    addressType: "EXTERNAL",
  }
);

// Create 2 Load Balancers
// - One that accepts https traffic and forwards it to the app.
// - One that accepts http traffic and only does a redirect to the https load balancer.

const neg = new gcp.compute.RegionNetworkEndpointGroup(`${SLSL}-region-neg`, {
  networkEndpointType: "SERVERLESS",
  region: LOCATION,
  cloudRun: {
    service: service.name,
  },
});

const backend = new gcp.compute.BackendService(`${SLSL}-backend-service`, {
  loadBalancingScheme: "EXTERNAL_MANAGED",
  backends: [
    {
      group: neg.selfLink,
    },
  ],
});

const urlMap = new gcp.compute.URLMap(`${SLSL}-url-map`, {
  defaultService: backend.name,
});

const cert = new gcp.compute.ManagedSslCertificate(`${SLSL}-ssl-cert`, {
  name: SLSL,
  managed: {
    domains: config
      .requireSecret("additional_allowed_hosts")
      .apply((s) => s.split(",")),
  },
});

const targetProxy = new gcp.compute.TargetHttpsProxy(`${SLSL}-https-proxy`, {
  sslCertificates: [cert.name],
  urlMap: urlMap.name,
});

const redirectUrlMap = new gcp.compute.URLMap(`${SLSL}-redirect-url-map`, {
  defaultUrlRedirect: {
    redirectResponseCode: "MOVED_PERMANENTLY_DEFAULT",
    httpsRedirect: true,
    stripQuery: false,
  },
});

const redirectProxy = new gcp.compute.TargetHttpProxy(`${SLSL}-http-proxy`, {
  urlMap: redirectUrlMap.name,
});

new gcp.compute.GlobalForwardingRule(`${SLSL}-http-gfr`, {
  loadBalancingScheme: "EXTERNAL_MANAGED",
  ipAddress: staticIp.address,
  portRange: "80",
  target: redirectProxy.selfLink,
});

new gcp.compute.GlobalForwardingRule(
  `${SLSL}-https-gfr`,
  {
    loadBalancingScheme: "EXTERNAL_MANAGED",
    ipAddress: staticIp.address,
    portRange: "443",
    target: targetProxy.selfLink,
  },
  {
    deleteBeforeReplace: true,
  }
);
