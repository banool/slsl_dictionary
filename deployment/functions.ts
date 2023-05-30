import * as pulumi from "@pulumi/pulumi";
import * as gcp from "@pulumi/gcp";
import { gcpServices } from "./project";
import { adminBucket, mediaBucket } from "./storage";
import { ADMIN_LOCATION, SLSL } from "./common";
import * as fs from "fs";
import * as archiver from "archiver";
import { appServiceAccount } from "./iam";
import { adminService } from "./app";
import { RUN_EVERY_N_MINUTES } from "./common";

const ZIP_LOCATION = "/tmp/code.zip";

const config = new pulumi.Config();

// See https://github.com/pulumi/pulumi-google-native/issues/370. Even though I'm using
// the classic provider, I was still seeing a problem where the function would use the
// old code after an update until I set replaceOnChanges on both of these resources.

// Zip up the code that we'll upload.
function zipCode() {
  if (fs.existsSync(ZIP_LOCATION)) {
    fs.unlinkSync(ZIP_LOCATION);
  }
  const archive = archiver("zip");
  archive.on("error", function (err) {
    throw err;
  });
  const output = fs.createWriteStream(ZIP_LOCATION);
  archive.pipe(output);
  archive.directory("dump_function/", false);
  archive.finalize();
}

zipCode();

// Upload the zip file containing the code to the bucket.
const archive = new gcp.storage.BucketObject(
  `${SLSL}-dump-function-archive`,
  {
    bucket: adminBucket.name,
    source: new pulumi.asset.FileAsset(ZIP_LOCATION),
    name: "functions/dump_function.zip",
  },
  { replaceOnChanges: ["*"] }
);

// Create the Cloud Function.
export const func = new gcp.cloudfunctions.Function(
  `${SLSL}-dump-function`,
  {
    description:
      "Function to read the DB and dump it to a file in the media bucket",
    runtime: "python310",
    serviceAccountEmail: appServiceAccount.email,
    minInstances: 0,
    maxInstances: 1,
    region: ADMIN_LOCATION,
    availableMemoryMb: 256,
    sourceArchiveBucket: adminBucket.name,
    sourceArchiveObject: archive.name,
    triggerHttp: true,
    httpsTriggerSecurityLevel: "secure-always",
    entryPoint: "main",
    environmentVariables: {
      // Take note of this. The function runs in the admin region but it dumps the data
      // to the media bucket, which is located near the users of the app.
      bucket_name: mediaBucket.name,
      dump_auth_token: config.requireSecret("dump_auth_token"),
      cloud_run_instance_url: adminService.statuses[0].url,
      cache_duration_secs: RUN_EVERY_N_MINUTES * 60,
    },
  },
  { dependsOn: [gcpServices.cloudfunctions], replaceOnChanges: ["*"] }
);
