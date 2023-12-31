import * as gcp from "@pulumi/gcp";
import * as pulumi from "@pulumi/pulumi";
import { ADMIN_LOCATION, MEDIA_LOCATION, SITE, SLSL } from "./common";
import { createLoadBalancer } from "./utils";

// Create a bucket that we'll use for the admin site (static content and cloud functions).
export const adminBucket = new gcp.storage.Bucket("slsl-admin-bucket", {
  location: ADMIN_LOCATION,
  cors: [
    {
      origins: ["*"],
      methods: ["GET", "HEAD", "PUT", "POST", "DELETE"],
      responseHeaders: ["*"],
    },
  ],
  uniformBucketLevelAccess: true,
});

// Create a bucket that we'll use for media data (videos and dump).
export const mediaBucket = new gcp.storage.Bucket("slsl-media-bucket", {
  location: MEDIA_LOCATION,
  cors: [
    {
      origins: ["*"],
      methods: ["GET", "HEAD", "PUT", "POST", "DELETE"],
      responseHeaders: ["*"],
    },
  ],
  uniformBucketLevelAccess: true,
});

// Make the buckets accessible to the public internet.
new gcp.storage.BucketIAMMember(
  "admin-public-access",
  {
    member: "allUsers",
    role: "roles/storage.objectViewer",
    bucket: adminBucket.name,
  },
  { dependsOn: [adminBucket] }
);

new gcp.storage.BucketIAMMember(
  "media-public-access",
  {
    member: "allUsers",
    role: "roles/storage.objectViewer",
    bucket: mediaBucket.name,
  },
  { dependsOn: [mediaBucket] }
);

// Set up Cloud CDN, which is really just a fancy LB in front of the bucket. This
// returns the IP for the CDN.
export const createCloudCdn = (
  namePrefix: string,
  bucket: gcp.storage.Bucket,
  options?: pulumi.ComponentResourceOptions
) => {
  // Enable the storage bucket as a CDN.
  const backendBucket = new gcp.compute.BackendBucket(
    `${namePrefix}-backend-bucket`,
    {
      bucketName: bucket.name,
      enableCdn: true,
    },
    options
  );

  // Provision a global IP address for the CDN.
  const ip = new gcp.compute.GlobalAddress(`${namePrefix}-ip`, {});

  // Create the load balancer for the bucket.
  createLoadBalancer({
    prefixName: `${namePrefix}-cdn`,
    ip: ip.address,
    backendName: backendBucket.selfLink,
    domains: [`cdn.${SITE}`],
  });

  return ip;
};

export const mediaCdnIp = createCloudCdn(`${SLSL}-media`, mediaBucket);
