import * as gcp from "@pulumi/gcp";
import { ADMIN_LOCATION, MEDIA_LOCATION } from "./common";

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
