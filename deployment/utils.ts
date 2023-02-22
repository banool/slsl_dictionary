import * as pulumi from "@pulumi/pulumi";

export function buildEnvObject(
  name: string,
  value: string | pulumi.Output<string>
) {
  if (typeof value == "string") {
    value = pulumi.output(value);
  }
  return { name: name, value: value };
}
