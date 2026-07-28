#!/usr/bin/env bash
# Provisioning script for a fresh Scaleway Mac mini lease (playbook §3.7).
# Every lease is a clean machine (no confirmed snapshot feature on Scaleway's
# macOS tier) — run this once at the start of each lease.
set -euo pipefail

echo "==> Installing Xcode command line tools"
xcode-select --install || true

echo "==> Cloning repo"
read -rp "Git remote URL: " REPO_URL
git clone "$REPO_URL" ~/TennisAnalyzer

# TODO: import signing certificate / provisioning profile once Apple developer
# account and certs exist (playbook §3.7, §8).

# TODO: install any Swift package dependencies once the Xcode project exists.

echo "==> Done. cd ~/TennisAnalyzer/ios-app and open the Xcode project."
