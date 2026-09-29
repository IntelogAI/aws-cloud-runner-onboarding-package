# Internal AWS customer onboarding procedure

This document is for Intelog operations and customer-success users. It contains no customer credentials and is safe to keep with the shareable onboarding package.

## One integration per boundary

Create a separate integration for each combination of:

- Intelog tenant;
- AWS account;
- environment (`development`, `staging`, or `production`);
- allowed AWS region.

Never reuse a token audience between customer AWS accounts. A suggested format is:

```text
intelog-aws:<tenant-slug>:<aws-account-id>:<random-integration-id>
```

Keep the audience under 255 characters and treat it as an identifier, not a secret.

## Information to send the customer

Provide the repository or release archive and confirm:

- expected 12-digit AWS account ID;
- unique token audience;
- approved resource region;
- expected role name, normally `IntelogCloudRunner`.

The Google service-account subject and authorized-party values are maintained in `onboarding.env.example`. They identify the Intelog runner; they are not AWS credentials.

## Information returned by the customer

Ask the customer to return only the wrapper outputs:

- `RoleArn`;
- `AwsAccountId`;
- `AllowedRegion`;
- `TokenAudience`.

Reject the response if the account ID, audience, region, or role name differs from the values issued for the integration.

## Backend registration

Create an `external_cloud_accounts` record scoped to the correct tenant and environment:

```json
{
  "tenantId": "<tenant ObjectId>",
  "awsAccountId": "<12-digit account ID>",
  "environment": "staging",
  "roleArn": "arn:aws:iam::<account-id>:role/IntelogCloudRunner",
  "webIdentityAudience": "<unique audience>",
  "allowedRegions": ["<approved region>"],
  "enabled": false
}
```

Keep the record disabled until an Intelog runner validation job successfully calls `sts:GetCallerIdentity` using the returned role. Enable the record only after the returned account and role match the registration request.

## Runtime behavior

After onboarding, the customer does not run this package for each deployment. The Intelog backend selects the tenant-scoped account record, creates a short-lived Kubernetes runner Job, and requests a Google identity token with that integration's audience. AWS STS exchanges the token for a temporary role session.

## Revocation

If either party requests revocation:

1. Disable the `external_cloud_accounts` record immediately.
2. Ask the customer to delete the CloudFormation stack.
3. Confirm the IAM role no longer exists.
4. Retain the audit event without retaining identity tokens or credentials.
