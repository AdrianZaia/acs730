# Assignment 1: Multi-Environment Deployment Pipeline

## Introduction

This assignment builds on the previous Terraform and AWS deployment labs by introducing reusable infrastructure modules, environment separation, remote state management, and automated CI/CD deployments. The goal was to create a deployment pipeline capable of deploying the same application infrastructure to development, staging, and production environments while maintaining separate configurations and Terraform states.

I built a reusable Terraform module that provisions the application's infrastructure, including networking, security, an EC2 web server, and CloudWatch monitoring. I then created separate environment directories that use the same module with different configuration values. GitHub Actions was used to automate Terraform validation and deployments, with a manual approval requirement before production changes could be applied. I also implemented environment-scoped credentials, explored AWS OIDC trust policies, and used AWS Systems Manager Parameter Store to securely retrieve an application secret.

## Reusable Module

The module at `assignment1/terraform/modules/app` creates a VPC, two public subnets (built with `for_each`), an internet gateway, a route table, a security group with a dynamic ingress block, an EC2 web server running nginx, a lookup of an SSM parameter, and a CloudWatch alarm.

Inputs: `environment` (validated to dev, staging or prod), `owner`, `project`, `vpc_cidr`, `public_subnets`, `ingress_rules`, `instance_type`.

Outputs: `vpc_id`, `subnet_ids`, `web_instance_id`, `web_public_ip`, `web_url`, `cpu_alarm_name`, and a sensitive `db_password`.

Every resource name is prefixed with the environment, so the three environments cannot collide.

## Environment Directories

`dev/`, `staging/` and `prod/` each call the same module with their own values: VPC CIDRs 10.10.0.0/16, 10.20.0.0/16 and 10.30.0.0/16, and `t3.small` for prod instead of `t3.micro`. Each directory has its own S3 backend key (`assignment1/<env>/terraform.tfstate`) in the shared state bucket, with `use_lockfile` for state locking, so their states never collide.

## GitHub Environments

`staging` has no protection rules, so it applies automatically on merge to `main`. `prod` requires one manual reviewer and can only be deployed from `main`. The workflow is `.github/workflows/assignment1.yml`, scoped with `paths: assignment1/**`. On pull requests only `validate` runs (format check and `terraform validate` for all three environments). After the merge to `main` (PR #14), `deploy-staging` ran by itself, then `deploy-prod` waited for approval and completed. The whole run took 2m 55s.

## Scoped Credentials and OIDC Trust Policy

The three AWS secrets (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`) now exist only as environment secrets on `staging` and `prod`, and the repository-level copies are deleted. Each session they are refreshed with `./scripts/refresh-gha-creds.sh AdrianZaia/acs730 staging prod`.

AWS Academy does not allow creating IAM OIDC providers or roles, so this is the trust policy I would deploy in a real AWS account for the prod role:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:AdrianZaia/acs730:environment:prod"
        }
      }
    }
  ]
}
```

What each condition prevents:

**Principal:** The `Principal` specifies which identity provider is trusted to request access to the AWS role. By restricting it to GitHub's OIDC provider, it prevents unrelated identity providers or AWS accounts from assuming the role.

**Action:** The `Action` restricts the permitted authentication operation to `sts:AssumeRoleWithWebIdentity`. This prevents the identity from using other STS actions to assume the role through an unintended authentication method.

**aud:** The `aud` condition requires the token's audience to be `sts.amazonaws.com`, ensuring that the token was intended for AWS Security Token Service rather than another service that might accept GitHub-issued tokens.

**sub:** The `sub` condition restricts role assumption to jobs from this specific repository that target the `prod` GitHub Environment. This prevents other repositories, and other environments such as development and staging, from assuming the production role. GitHub only issues the `environment:prod` claim to a job that has passed the environment's protection rules, so the reviewer approval and the `main`-only branch policy are enforced as well.

## Real Deployment

PR #14 was merged into `main`. The `assignment1` run applied staging automatically, then paused at the prod gate until I approved it, and prod completed successfully. Both environments were deployed to the AWS Academy account in us-east-1.

## Secrets Management

The application secret is an SSM Parameter Store SecureString at `/assignment1/<env>/db_password`, created by hand with the AWS CLI so the value never appears in the Terraform code. The module reads it with a `data "aws_ssm_parameter"` source and exposes it only as a `sensitive` output. Data source values still end up in Terraform state, so the state bucket must be encrypted and access-restricted (the backend uses `encrypt = true`).

## CloudWatch Alarm

`aws_cloudwatch_metric_alarm.cpu_high` watches the `CPUUtilization` metric (namespace `AWS/EC2`) of the web instance and goes into alarm when the 5-minute average exceeds 70% for two consecutive periods. It is defined in the module, so every environment gets it.

## Recommendation: GitHub Actions vs AWS-Native Pipeline

For this assignment, I would recommend GitHub Actions over an AWS-native pipeline because the project is already managed through GitHub, and integrating the deployment workflow directly with the repository provides a simpler and more efficient development process. Both solutions can automate infrastructure deployments, but GitHub Actions offers advantages in source control integration, workflow flexibility, and visibility into the development process.

The first major factor is integration with source control. GitHub Actions is directly integrated with GitHub repositories, allowing workflows to automatically run when code is pushed, pull requests are created, or changes are merged into specific branches. In this assignment, I used path filtering to ensure that the workflow only runs when files within `assignment1/` are modified. Pull requests trigger validation before changes are merged, while merging into `main` automatically initiates the staging deployment. This creates a straightforward development workflow without requiring additional AWS services to connect the source repository to the deployment pipeline.

The second factor is deployment control and security. GitHub Actions supports environment-specific deployment rules, secrets, and approval requirements. I configured staging to deploy automatically while requiring a manual reviewer before production deployment. This provides a separation between testing and production changes and reduces the risk of accidentally deploying unreviewed infrastructure modifications. Environment-scoped secrets also prevent credentials from being unnecessarily exposed to unrelated workflows. Although AWS-native pipelines can provide similar security controls through IAM, pipeline permissions, and approval stages, GitHub Actions allows these controls to be managed directly alongside the repository.

The third factor is ease of maintenance and visibility. GitHub Actions workflows are defined as YAML files and stored within the repository, allowing deployment logic to be version-controlled, reviewed, and modified alongside Terraform code. The workflow execution history also provides visibility into validation results, deployment progress, failures, and approval requirements. This makes troubleshooting easier because developers can review both infrastructure changes and pipeline execution within the same platform.

AWS-native services, such as CodePipeline and CodeBuild, would be a strong alternative for organizations that primarily operate within AWS. They provide deeper integration with AWS services and may be preferable in environments with strict AWS governance requirements or centralized cloud deployment management. However, they would introduce additional configuration and service management for this assignment.

Overall, GitHub Actions was the more practical choice because it provided automated validation, multi-environment deployment, production approval controls, and credential management within an existing GitHub workflow. It allowed me to achieve the assignment's deployment objectives while keeping the pipeline straightforward, maintainable, and easy to understand.

## Conclusion

This assignment demonstrated how Terraform modules and CI/CD pipelines can be used to deploy and manage infrastructure across multiple environments. By creating a reusable application module, I was able to deploy the same infrastructure to development, staging, and production while maintaining separate configurations and remote Terraform states. This reduced duplication and made the infrastructure easier to maintain.

I also implemented a GitHub Actions workflow that validates Terraform configurations through pull requests and automatically deploys staging after changes are merged into `main`. Production deployments were protected by a manual approval requirement, demonstrating how deployment controls can reduce the risk of unintended infrastructure changes. Environment-scoped credentials, encrypted remote state, and AWS Systems Manager Parameter Store were also used to improve secrets management.

The successful deployment of both staging and production to AWS Academy confirmed that the pipeline worked as intended. Overall, this assignment provided practical experience with infrastructure as code, reusable modules, remote state management, CI/CD automation, deployment approvals, secrets management, and cloud monitoring. These are important concepts for building reliable, secure, and maintainable cloud infrastructure in a real-world environment.
