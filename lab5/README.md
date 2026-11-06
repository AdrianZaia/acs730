# Lab 5: Terraform with LocalStack and CI

## What I built

One Terraform configuration that targets either real AWS or LocalStack,
switched by a single `use_localstack` variable. It creates a VPC
(10.42.0.0/16), public subnets built with `for_each`, an internet gateway,
a route table with a default route, route table associations, a security
group with a dynamic ingress block, and an EC2 instance configured by
`user_data`. A GitHub Actions workflow (`lab5-ci.yml`) runs
`fmt` and `validate` first, then plans and applies against LocalStack only
if those pass. Both jobs are required status checks on `main`, which I
proved by breaking a variable name on purpose and watching the merge
button stay blocked.

## Why for_each instead of count

(Use your Part 7 notes here. The usual argument:) `count` identifies
resources by position, so removing or reordering an item in the list
shifts every index after it and Terraform wants to destroy and recreate
subnets that did not change. `for_each` identifies them by key ("a", "b"),
so each subnet keeps a stable address in state. It also lets the route
table association loop over `aws_subnet.public` directly, with no index
arithmetic, because the keys carry over.

## Why not plan and apply against real AWS on every pull request

- **Cost is per run, not per month.** Every pull request would build and
  destroy real infrastructure. With 27 students pushing a few times each,
  that is thousands of cycles against one fixed $50 budget. LocalStack is
  free and leaves nothing behind.
- **It needs a long-lived credential in the repository.** Applying from
  Actions means an access key stored in GitHub secrets, which can leak and
  must be rotated. In an Academy account IAM writes are denied, so the key
  cannot be scoped down and the only one that works is a broad one.
- **Academy sessions expire.** Lab credentials last hours, so a pull
  request opened Saturday night fails Sunday morning for a reason
  unrelated to the code. People learn to ignore red checks, and a check
  people ignore is worse than no check.
- **It is slow and flaky.** Each run takes minutes, and it can hit API
  rate limits, eventual-consistency errors, and concurrent pull requests
  colliding on names and state in one account.
- **The honest limit of LocalStack.** A green LocalStack run proves the
  configuration is coherent and the dependency graph builds. It does not
  prove IAM is right, because LocalStack does not enforce it, or that
  `user_data` works, because LocalStack never boots the instance. The real
  check belongs on merge or on a schedule, once, not on every pull request.
