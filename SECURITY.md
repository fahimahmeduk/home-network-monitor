# Security policy

## Supported version

Security fixes are applied to the latest release.

## Sensitive information

Never include the following in a public issue, pull request, screenshot or log excerpt:

- Telegram bot tokens
- Telegram chat IDs
- Public IP addresses
- Private hostnames or internal addresses that should remain confidential
- The live `/opt/home-network-monitor/config.conf`

The repository must contain placeholders only.

## Reporting a vulnerability

Do not open a public issue containing exploit details or credentials. Contact the repository owner privately through an available GitHub profile contact method and include:

- A concise description
- Affected version
- Reproduction steps without real secrets
- Expected security impact

## Deployment model

Home Network Monitor:

- Opens no inbound network ports
- Sends outbound HTTPS requests to Telegram and the configured ISP lookup endpoint
- Runs scheduled scripts as the installing user
- Uses `sudo` during installation for `/opt` and `/usr/local/bin`
- Stores the runtime configuration with mode `0600`

Review all scripts before installation, particularly when installing a fork.
