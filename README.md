# PR Daemon

A macOS menu bar app that monitors your GitHub pull requests and helps you stay on top of reviews, comments, and CI status.

## Features

- **Menu bar integration** — lives in your menu bar, shows PR status at a glance
- **GitHub polling** — periodically fetches your open PRs and highlights ones needing attention
- **Notifications** — alerts for new comments, completed checks, and submitted reviews
- **AI code review auto-fix** — detects AI reviewer comments (e.g. CodeRabbit) and can auto-fix them using Claude or Codex
- **Quick actions** — open PRs in browser, launch coding agents in your preferred terminal
- **Terminal support** — works with Terminal, iTerm2, Warp, Kitty, Alacritty, WezTerm, and Hyper
- **Git worktree support** — configurable worktree directory for parallel development
- **Auto-updates** — built-in updates via Sparkle

## Requirements

- macOS 14.0+
- GitHub personal access token
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (for building from source)

## Build

```bash
# Generate Xcode project and build
make build

# Build and run
make run

# Clean build artifacts
make clean
```

## Install

Download the latest `.dmg` from [Releases](https://github.com/banyudu/pr-daemon/releases).

## Tech Stack

- Swift / SwiftUI
- XcodeGen for project generation
- Sparkle for auto-updates
- GitHub Actions for CI/CD and notarized releases
