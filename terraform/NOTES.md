# M3 Notes — Provision ShipFast Infrastructure with Terraform

Bucket: `shipfast-artifacts-dev-483175530654` (us-east-1)
Terraform v1.17.0 · AWS provider 5.100.0 · IAM user `adminUser` (not root)

## Task 3 — plan prediction vs reality

**Prediction:** 3 resources added (bucket, versioning, encryption). The data source
is a read, not a create. `arn`, `bucket_domain_name`, `region`, `hosted_zone_id`,
`tags_all` and both outputs would be "known after apply", because S3 only assigns
them once the bucket exists.

**Reality:** matched. The first apply reported `3 added, 0 changed, 0 destroyed`.
The only thing I had not predicted was that the bucket *name* itself was known up
front — it is built from a variable and the account ID, both of which Terraform
already knows before it talks to AWS.

## Task 5 — address vs ID

In `terraform.tfstate`: `serial` = 15 after the experiments, `lineage` =
`6cdb4232-276c-7d22-9831-b53af1cd1da1` (unchanged through every apply), and the
real bucket ID is
`shipfast-artifacts-dev-483175530654`.

The address (`aws_s3_bucket.artifacts`) is the name *my code* uses; the ID is the
name *AWS* uses. State is the lookup table between the two, which is how Terraform
knows that a block I edit refers to a bucket that already exists instead of a new
one to create.

## Task 6 — the four experiments

**1. Apply again with no changes** → `Apply complete! Resources: 0 added, 0 changed,
0 destroyed.` Terraform refreshed each resource, compared the real state to the
desired state, found no difference, and did nothing. Terraform is declarative: a
second apply is a no-op, not a second create.

**2. Tag `ManualChange = true` added outside Terraform** → plan showed
`0 to add, 1 to change, 0 to destroy`, with `- "ManualChange" = "true" -> null`.
Terraform finds it during the refresh at the start of the plan, when it re-reads
every resource from AWS. Because my `tags` block does not contain that tag, the
out-of-band change is drift, and apply deleted it. Code wins over the console.

**3. `terraform plan -var environment=staging`** → `3 to add, 0 to change,
3 to destroy`, each resource marked `-/+` with
`# forces replacement` on the `bucket` attribute. An S3 bucket name is its
identity; it cannot be renamed in place, so Terraform must delete and recreate.

**4. Plan with `terraform.tfstate` moved away** → `3 to add, 0 to change, 0 to
destroy`. With no state file Terraform has no record that it ever built anything,
so it wants to create all three from scratch — and that apply would fail with
`BucketAlreadyExists`. Terraform's plan is built from three inputs: the code, the
state and the real infrastructure. Remove the state and it becomes blind to what
it already owns.

## The five questions

**1. What did your second apply do, and why?**
Nothing — `0 added, 0 changed, 0 destroyed`. It refreshed the three resources,
found the real infrastructure already matched the configuration, and had no work
to do. That is what declarative means: the code describes the end state, not the
steps.

**2. How does Terraform know about the tag you added by hand, and what did it do?**
At the start of every plan Terraform refreshes state by reading each resource back
from the AWS API, so it saw a tag that is in AWS but not in my code. It reported it
as drift (`1 to change`) and the apply removed it, bringing reality back in line
with the configuration.

**3. What does `-/+` with "forces replacement" mean?**
The attribute being changed cannot be updated in place, so Terraform will destroy
the resource and create a new one. For a bucket that is survivable — mine was
empty. For a database it would be alarming: replacement means the old instance and
everything in it is deleted, so a careless rename of an identifying attribute can
wipe production data. That is what `prevent_destroy` and careful plan-reading are
for.

**4. Why must `terraform.tfstate` never go into Git, and where should it live?**
State holds the full attributes of every resource in plain text, including values
that are secret for other resource types (passwords, keys, connection strings), so
committing it leaks them to everyone with repo access. It also has no locking in
Git, so two people applying at once would silently corrupt it. A team keeps it in a
remote backend — for us, an S3 bucket with versioning and encryption plus state
locking — so it is shared, locked and recoverable.

**5. Where does Terraform get your AWS credentials, and where must they never appear?**
From the standard AWS credential chain, the same one the CLI uses: environment
variables, then `~/.aws/credentials` from `aws configure`, then an instance or OIDC
role. My `provider "aws"` block contains only `region`. They must never appear in
`.tf` files, in `.tfvars`, in state, in Git, in CI logs, in chat or in screenshots.
