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
      // The default mode is CACHE_ALL_STATIC. In this mode, all static content is
      // cached. If Expires is present or max-age is present in Cache-Control, that
      // value will be used to determine freshness. If not, the default TTL is used.
      // Normally JSON is not considered a static file, but all files served from GCS
      // have the Cache-Control header attached, so they're all cached with the
      // CACHE_ALL_STATIC mode, meaning USE_ORIGIN_HEADERS and CACHE_ALL_STATIC are
      // mostly functionally equivalent, so we just use CACHE_ALL_STATIC. This way the
      // default TTL we set here will be used rather than the default coming from GCS.
      // See more here: https://cloud.google.com/cdn/docs/caching#static
      cdnPolicy: {
        cacheMode: "CACHE_ALL_STATIC",
        // We don't expect a single video file to ever change so we set a really long
        // TTL for the default. The dump file has its own TTL set explicitly.
        defaultTtl: 604800,
        maxTtl: 604800,
        // This is true by default, we're just being explicit.
        requestCoalescing: true,
      },
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
