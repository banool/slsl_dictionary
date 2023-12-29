import * as pulumi from "@pulumi/pulumi";
import * as gcp from "@pulumi/gcp";

export function buildEnvObject(
  name: string,
  value: string | pulumi.Output<string>
) {
  if (typeof value == "string") {
    value = pulumi.output(value);
  }
  return { name: name, value: value };
}

// Given you generally have a one to one relationship between host rules and path
// matchers, we take them in together.
export type AdditionalUrlMapRule = {
  hostRule: gcp.types.input.compute.URLMapHostRule;
  pathMatcher: gcp.types.input.compute.URLMapPathMatcher;
};

// This sets up a load balancer that redirects HTTP to HTTPS and then forwards HTTPS to
// the backend. You can provide additional rules for the main redirect, e.g. a host
// rule that matches www.mysite.com and then a path matcher that redirect requests for
// that URL to mysite.com. We don't do any validation at the moment that the redirects
// make sense given the dnsRecords. We accept `domains` directly rather than DNS
// records because we don't manage DNS using GCP for this project.
export const createLoadBalancer = ({
  prefixName,
  ip,
  backendName,
  domains,
  additionalUrlMapRules,
  parent,
  projectName,
}: {
  prefixName: string;
  ip: pulumi.Output<string>;
  backendName: pulumi.Output<string>;
  domains: pulumi.Input<pulumi.Input<string>[]>;
  additionalUrlMapRules?: pulumi.Input<AdditionalUrlMapRule[]>;
  parent?: pulumi.ComponentResource;
  projectName?: string;
}) => {
  // All the stuff from this point is for setting up the https LB and setting it up to
  // route requests to the backend.

  const httpsUrlMap = new gcp.compute.URLMap(
    `${prefixName}-https-urlmap`,
    {
      hostRules: pulumi
        .output(additionalUrlMapRules)
        .apply((rules) => rules?.map((r) => r.hostRule) ?? []),
      pathMatchers: pulumi
        .output(additionalUrlMapRules)
        .apply((rules) => rules?.map((r) => r.pathMatcher) ?? []),
      defaultService: backendName,
      project: projectName, // needs to be in the same project as the backend, if specified
    },
    {
      parent,
    }
  );

  const sslCert = new gcp.compute.ManagedSslCertificate(
    `${prefixName}-ssl`,
    {
      managed: {
        domains,
      },
      project: projectName, // needs to be in the same project as the backend, if specified
    },
    {
      parent,
    }
  );

  const targetHttpsProxy = new gcp.compute.TargetHttpsProxy(
    `${prefixName}-https-proxy`,
    {
      sslCertificates: [sslCert.name],
      urlMap: httpsUrlMap.name,
      project: projectName, // URLMap needs to be in the same project as the backend, if specified
    },
    {
      parent,
    }
  );

  const httpsLb = new gcp.compute.GlobalForwardingRule(
    `${prefixName}-lb`,
    {
      loadBalancingScheme: "EXTERNAL_MANAGED",
      ipAddress: ip,
      portRange: "443",
      target: targetHttpsProxy.selfLink,
      project: projectName, // needs to be in the same project as the backend, if specified
    },
    {
      parent,
    }
  );

  // All the stuff from this point is for setting up the http LB and setting it up to
  // redirect requests to the https LB.

  const httpToHttpsRedirectUrlMap = new gcp.compute.URLMap(
    `${prefixName}-redirect-urlmap`,
    {
      defaultUrlRedirect: {
        redirectResponseCode: "MOVED_PERMANENTLY_DEFAULT",
        httpsRedirect: true,
        stripQuery: false,
      },
      project: projectName, // needs to be in the same project as the backend, if specified
    },
    {
      parent,
    }
  );

  const redirectProxy = new gcp.compute.TargetHttpProxy(
    `${prefixName}-redirect-proxy`,
    {
      urlMap: httpToHttpsRedirectUrlMap.name,
      project: projectName, // needs to be in the same project as the backend, if specified
    },
    {
      parent,
    }
  );

  const redirectLb = new gcp.compute.GlobalForwardingRule(
    `${prefixName}-redirect-lb`,
    {
      loadBalancingScheme: "EXTERNAL_MANAGED",
      ipAddress: ip,
      portRange: "80",
      target: redirectProxy.selfLink,
      project: projectName, // needs to be in the same project as the backend, if specified
    },
    {
      parent,
    }
  );
};
