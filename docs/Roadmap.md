# Roadmap

Home Network Monitor prioritises reliability, small resource usage, privacy and maintainability. Features are added only when they improve the practical monitoring experience without turning the project into a large observability platform.

## Current release

### v1.3.0

- Download and upload monitoring
- Primary and fallback speed-test servers
- Same-run confirmation of degraded results
- Latency and packet-loss reporting
- Network Health Score
- Independently verified ISP and test-server reporting
- Improved CLI status
- Dedicated version command
- Automatic log rotation and retention
- Safe CSV schema migration
- Configurable connectivity targets
- Daily averages and uptime
- Automated simulated tests
- GitHub Actions validation

## Candidate next release

### v1.4.0

Potential improvements:

- Weekly summary command and notification
- Monthly performance summary
- Historical trend command using existing CSV data
- Optional notification provider such as ntfy
- Additional installer validation

The next release scope will be selected from real usage rather than implemented all at once.

## Future ideas

- Prometheus metrics
- Optional Grafana example dashboard
- Docker image
- REST API
- Additional notification providers
- Cross-platform support

These remain ideas, not commitments. They must preserve the lightweight design.

## Deliberate non-goals

- Replacing enterprise network monitoring
- Requiring a database
- Opening inbound ports
- Collecting browsing history
- Running continuous high-bandwidth tests
- Adding a web interface without a clear operational benefit

## Design principles

- Human-readable output
- Minimal dependencies
- Safe upgrades
- No credentials in Git
- Useful alerts rather than frequent alerts
- Transparent calculations
- Documentation that matches the released behaviour
