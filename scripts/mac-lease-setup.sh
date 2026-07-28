#!/usr/bin/env bash
# Provisioning script for a fresh Scaleway Mac mini lease (docs/mac-setup.md,
# playbook §3.7). Every lease is a clean machine (no snapshot feature on
# Scaleway's macOS tier) — run this over SSH right after connecting.
#
# Covers only what's scriptable without a GUI. Xcode/Apple-ID sign-in and
# project creation still need Screen Sharing — see docs/mac-setup.md §4.
set -euo pipefail

echo "==> Xcode (preinstalled by Scaleway)"
xcodebuild -version
sudo xcodebuild -license accept
sudo xcodebuild -runFirstLaunch
xcrun simctl list devices available

echo "==> Installing Homebrew"
if ! command -v brew >/dev/null 2>&1; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
  echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
fi

echo "==> Git identity"
read -rp "Git user.name: " GIT_NAME
read -rp "Git user.email: " GIT_EMAIL
git config --global user.name "$GIT_NAME"
git config --global user.email "$GIT_EMAIL"

echo "==> GitHub CLI + repo clone"
brew install gh
gh auth login
read -rp "GitHub repo (owner/name), e.g. yourname/TennisAnalyzer: " GH_REPO
gh repo clone "$GH_REPO" ~/TennisAnalyzer

echo "==> Done. Open Screen Sharing next: sign into Xcode with your Apple ID"
echo "    and create the ios-app project — see docs/mac-setup.md §4."
