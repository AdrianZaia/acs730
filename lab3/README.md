# Lab 3

Instructions for this section will be provided in class and on Blackboard when we reach it.

Put your work for Lab 3 in this folder.

In a real AWS account, CI/CD pipelines and automation should authenticate with OIDC federation (for example, GitHub Actions assuming an IAM role) instead of stored access keys, because OIDC issues short-lived credentials on demand, leaves no long-lived secret in the repo or CI settings to leak, rotate, or forget, and lets the role’s trust policy restrict which repository and branch can assume it.
This course uses temporary session-scoped credentials (access key, secret key, and session token) because the lab environment doesn’t give students permission to create IAM roles or identity providers, and if they leak the damage is limited because they expire when the lab session ends and only carry the restricted permissions of the sandbox account, which has a spending cap and no access to anything outside it.

