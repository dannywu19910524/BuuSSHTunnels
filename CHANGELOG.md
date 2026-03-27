# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [1.0.0] - 2026-03-28

### Added

- Menubar app with NSStatusItem + NSPopover
- SSH tunnel management — add, edit, and delete tunnels
- Auto-reconnect with exponential backoff (2s, 4s, 8s... capped at 60s)
- Configurable max retries (default 999)
- System notifications every 30 reconnect attempts and at retry limit
- Launch at login support via ServiceManagement
- File logging to `~/Library/Application Support/Tunnel/tunnel.log`
- JSON config persistence to `~/Library/Application Support/Tunnel/config.json`
- SSH command sanitization — strips `-f`, `-N`, `-T` flags, adds keepalive options

### Fixed

- Strip `-f` flag from SSH commands to prevent background process breaking process management
- Port check false positive from orphaned processes (pre-listening port detection)
- Synchronous state update on tunnel stop (avoid deallocation race in terminationHandler)
