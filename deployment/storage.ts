import * as gcp from "@pulumi/gcp";
import { LOCATION } from "./common";

// Create a bucket that we'll use for both static and media files.
export const mainBucket = new gcp.storage.Bucket("slsl-main-bucket", {
  location: LOCATION,
  uniformBucketLevelAccess: true,
});

// Make the bucket accessible to the public internet.
new gcp.storage.BucketIAMMember(
  "public-access",
  {
    member: "allUsers",
    role: "roles/storage.objectViewer",
    bucket: mainBucket.name,
  },
  { dependsOn: [mainBucket] }
);
