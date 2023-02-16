import * as gcp from "@pulumi/gcp";
import { LOCATION } from "./common";

// Create a bucket for media files.
const mediaBucket = new gcp.storage.Bucket("slsl-media", {
    location: LOCATION,
    uniformBucketLevelAccess: true,
});

// Create a bucket for static files.
const staticBucket = new gcp.storage.Bucket("slsl-static", {
    location: LOCATION,
    uniformBucketLevelAccess: true,
});

// Make both buckets public.
const mediaPublicRule = new gcp.storage.BucketAccessControl("slsl-media-public-rule", {
    bucket: mediaBucket.name,
    role: "READER",
    entity: "allUsers",
});
const staticPublicRule = new gcp.storage.BucketAccessControl("slsl-static-public-rule", {
    bucket: staticBucket.name,
    role: "READER",
    entity: "allUsers",
});

// Export the DNS name of the buckets.
export const mediaBucketName = mediaBucket.url;
export const staticBucketName = staticBucket.url;
