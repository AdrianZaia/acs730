# Lab 6: Ansible configuration management and a Packer golden AMI

Terraform builds two tagged EC2 instances with no port 22 ingress. An Ansible
role (`roles/webserver`) turns them into web servers, found through the
`amazon.aws.aws_ec2` dynamic inventory (the `Lab=lab6` tag) and reached over
AWS Systems Manager Session Manager. A GitHub Actions workflow runs the
converge right after `terraform apply`. The same role is baked into a golden
AMI with Packer, and I timed both paths from launch to HTTP 200.

## The three required sentences

**Runner-to-instance mechanism.** I used Session Manager (SSM), because it needs
no inbound port and no stored key: the instance dials out to SSM and the runner
authenticates with the same temporary session credentials it already has, so
there is no long-lived private key in repository secrets and no port 22 open
to a runner whose address keeps changing.

**What changed=0 on a second run proves.** It proves that every task checked the
real state of each host and found it already matching what the role asks for,
not that the playbook did nothing, which is why the same command is safe on a
brand-new instance, on a converged one, and from a pipeline on every merge.

**Why deregistering an AMI is not enough.** The AMI is only a pointer; the EBS
snapshot behind it is the stored data and the thing that bills, so
deregistering leaves the snapshot behind, and once the AMI is gone
`describe-images` can no longer tell you which snapshot belonged to it (I read
the snapshot id first, then deregistered the AMI and deleted the snapshot).

## Boot-to-ready comparison

| Path | Seconds | What it includes |
|---|---|---|
| Converge on boot (stock AL2023 + Ansible) | 123 | Terraform replacing the instance, boot, SSM agent registration, the six role tasks, service start |
| Golden AMI (Packer image) | 22 | `run-instances`, boot, service already enabled in the image |
| Packer build (one time) | 292 (4 m 52 s) | Build instance, converge, image, snapshot |

Caveat: the converge number starts the clock before `terraform apply -replace`,
which also spends about 30 seconds destroying the old instance. The golden
number starts at `run-instances`. The real gap is therefore somewhat smaller
than 123 vs 22, roughly 90 vs 22.

Both paths were verified without logging in. The converged page says
`Build: ansible-converge`, the golden instance says `Build: golden-ami`, and
`/baked.html` returned 200, which nothing in the role creates, so it can only
have come from the image.

## Where the time went in the slow path

Not in the Ansible logic. About 43 seconds was Terraform destroying and
creating the instance, and the rest was waiting for the SSM agent to register
and then running six tasks. The `dnf` task reported `ok`, not `changed`,
because `python3` and `rsync` are already in the AL2023 image, so package
downloads were not a factor this time. I did not time registration and the
playbook separately.

## What a golden AMI moves rather than removes

The work still happens, once at build time instead of on every launch. The
Packer build cost 292 seconds and each launch saves about 100 seconds, so the
image pays for itself at roughly three to four instances (a bit more once the
caveat above is counted). For a single instance I would have paid a full build
to save under two minutes.

## What breaks

- **Golden AMI:** the image is a frozen moment, so updates released after the
  bake are not in it and I need a rebuild cadence. I also cannot see inside it
  without the build log, whereas a playbook documents itself.
- **Converge on boot:** every launch depends on package mirrors and the SSM
  agent being reachable right then. A mirror outage means instances that boot
  and never become ready, and autoscaling at 3 a.m. is when I least want a
  network dependency in the boot path.

## Recommendation

Golden AMI, because we launch instances in groups and 22 seconds beats 123;
I would switch back to converge-on-boot if we launched a single instance
rarely or changed the configuration more often than we rebuild the image.

## Design notes

- **SSM transfer bucket and region.** The `aws_ssm` connection stages file
  transfers through an S3 bucket. The bucket and `ansible_aws_ssm_region` must
  both be `us-east-1`, otherwise the first task fails with `PermanentRedirect`.
  The connection name also had to be fully qualified as `amazon.aws.aws_ssm`;
  the short name `aws_ssm` was reported as not found on my Ansible 2.15.3.
- **Pipeline and Terraform state.** The runner starts with empty state, so its
  `apply` would have collided with the security group already created from the
  workstation. I destroyed the workstation copy first and let the runner build
  everything fresh, then removed the runner's resources by tag.
- **Idempotency on the role.** Variables live in `defaults/`, not `vars/`, so
  Packer can override `build_tag` with `--extra-vars`.

## Experiments

**1. Break idempotency on purpose.** Prediction: a `shell: mkdir -p` task
would report `changed=1` on the second run, and adding `creates:` would bring
it to `changed=0`. Result: both held (`changed=1` on both hosts on the second
run, then `changed=0` with `creates:`). Ansible cannot work this out itself
because a shell command is opaque to it, whereas a real module such as `file`
checks current state first and `creates:` gives Ansible a path to check.

**2. Make the inventory shrink.** Prediction: stopping one instance would drop
it from the graph through the `instance-state-name: running` filter, and
removing the filter would bring it back as an unreachable host. Result: with
the filter only the running instance appeared; without it both appeared and the
stopped host came back as `failed=1` (not `unreachable` as I predicted) while
the running host stayed `ok=7`. The filter is what keeps the playbook from
trying hosts that cannot answer.
