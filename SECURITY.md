# Security

Do not open a public issue containing AWS credentials, identity tokens, customer tenant IDs, or deployment logs containing sensitive values.

This onboarding flow does not require AWS access keys. If a credential is accidentally committed or shared, revoke it immediately and contact the Intelog security/operations team.

To revoke Intelog's access to a customer AWS account, delete the onboarding CloudFormation stack and ask Intelog to disable the corresponding external-cloud-account integration.
