import * as gcp from "@pulumi/gcp";
import { LOCATION } from "./common";

// Create a bucket for media files.
export const mediaBucket = new gcp.storage.Bucket("slsl-media", {
  location: LOCATION,
  uniformBucketLevelAccess: true,
});

// Create a bucket for static files.
export const staticBucket = new gcp.storage.Bucket("slsl-static", {
  location: LOCATION,
  uniformBucketLevelAccess: true,
});

// Export the DNS name of the buckets.
export const mediaBucketName = mediaBucket.url;
export const staticBucketName = staticBucket.url;
