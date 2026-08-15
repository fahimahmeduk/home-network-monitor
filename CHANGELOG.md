# Changelog

All notable changes to Home Network Monitor are documented here.

## [1.3.0] - 2026-08-15

### Added

- Upload-speed thresholds and reporting
- Primary-to-fallback server confirmation
- Ping-based packet-loss fallback
- Network Health Score
- ISP reporting
- Packet-loss source reporting
- Configurable connectivity targets
- Automatic log rotation and retention
- `network-monitor version`
- Automated simulated test suite
- GitHub Actions workflow

### Changed

- Poor results are confirmed during the same execution instead of waiting for the next 12-hour schedule
- Daily summaries calculate averages instead of repeating only the latest result
- CLI status formats every performance metric
- Daily summary schedule moved from 20:05 to 20:10
- Connectivity script rewritten as maintainable structured Bash
- Installer now migrates missing configuration settings and corrects runtime ownership

### Fixed

- Poor upload results being marked healthy
- A single unsuitable speed-test server causing misleading assessments
- Packet-loss data remaining unavailable when the Speedtest JSON object is empty
- Existing configuration becoming unreadable after a fresh root-owned installation
- Incorrect ISP labels caused by stale or inaccurate Speedtest.net caller metadata

### Security

- Telegram credentials remain outside the repository
- Configuration is enforced as mode `0600`
- Public output avoids bot credentials and public IP details

## [1.2.0]

- Smart download degradation alerts
- Recovery notifications
- Daily Telegram summary
- CSV status field and state tracking

## [1.1.0]

- Installer and uninstaller
- CLI deployment
- Idempotent cron setup

## [1.0.0]

- Initial connectivity monitoring
- Scheduled speed tests
- Telegram integration
- Basic status and logs
