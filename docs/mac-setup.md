# Mac Lease Setup — Phase 0

Step-by-step for provisioning a Scaleway Mac mini and getting to a running Xcode
project in the least possible billed time. Background/decisions: [decisions.md](decisions.md);
full rationale: [the playbook, §3.7](tennis-serve-app-full-playbook.md).

**Key fact that changes the plan:** Scaleway Mac minis ship with **Xcode already
installed** (latest version compatible with the OS) plus MacPorts and `fail2ban`.
There's no App Store sign-in or multi-GB Xcode download to wait through.

Sources: [Apple silicon quickstart](https://www.scaleway.com/en/docs/apple-silicon/quickstart/),
[FAQ](https://www.scaleway.com/en/docs/apple-silicon/faq/),
[connect via SSH](https://www.scaleway.com/en/docs/apple-silicon/how-to/connect-to-mac-mini-ssh/).

---

## 0. Before you start the lease (free — do this on Windows)

- [ ] Push this repo to GitHub, if not already pushed (billing hasn't started yet, no rush cost-wise, but do it before connecting so `gh repo clone` works immediately).
- [ ] Have your Apple ID ready. A free personal account is enough for Phase 0 — it gets you a personal signing team so you can build to Simulator/a personal device. The $99/yr Apple Developer Program enrollment is only needed later, for TestFlight/App Store (Phase 6).
- [ ] Decide your bundle-ID organization identifier now (e.g. `com.<yourname>`) so you're not thinking about naming mid-session.
- [ ] Optional: create a free [Sentry](https://sentry.io) account. Don't wire in the SDK yet — nothing to instrument until the app shell exists.

---

## 1. Order the Mac mini

Console: **Bare Metal → Apple silicon → Create**.

| Setting | Recommendation |
|---|---|
| Setup type | Standard |
| Availability zone | `PAR1` (offers M4 / M2 Pro / M2 — `PAR3` only has M1) |
| macOS version | Leave the **default** — a non-default version adds ~1 hour to provisioning |
| Bandwidth | Default is fine |
| Private Networks | Skip — not needed yet |
| Kernel extensions | Leave **off** (only needed for things like macFUSE; not used here) |
| Commitment | No commitment (hourly), or enable auto-delete-after-24h if the console offers it — Apple's licensing enforces a 24h minimum either way |

Accept the Bare Metal terms + macOS license, click create, wait for the "ready" notification.

---

## 2. Connect

You'll use two channels — SSH for everything scriptable, Screen Sharing only for the handful of steps that genuinely require a GUI.

- **SSH** — Mac mini's console **Overview** page shows the exact command under "SSH command":
  ```bash
  ssh <your_mac_mini_username>@<your_mac_mini_ip>
  ```
- **Screen Sharing / VNC** — same Overview page shows a **non-default port** (VNC port is randomized per instance). Use macOS's built-in Screen Sharing app (`vnc://<ip>:<port>`) or any VNC client pointed at `<ip>:<port>`.

**Do not enable FileVault.** It encrypts the disk and blocks remote SSH/Screen Sharing until someone enters the key at the physical machine — which doesn't exist for you here. There's no snapshot/recovery access either, so this would lock you out permanently.

---

## 3. Fully-scriptable setup — run over SSH first

Everything in this step needs no GUI. Run [`scripts/mac-lease-setup.sh`](../scripts/mac-lease-setup.sh) from this repo, or paste the commands directly:

```bash
# Confirm Xcode is present (preinstalled by Scaleway) and check its version
xcodebuild -version

# Accept the Xcode license non-interactively
sudo xcodebuild -license accept

# Install first-launch components (Simulator runtimes etc.) without the GUI wizard
sudo xcodebuild -runFirstLaunch

# Confirm simulator runtimes are ready
xcrun simctl list devices available

# Install Homebrew — Scaleway preinstalls MacPorts, but Homebrew is what
# almost all iOS tooling docs (fastlane, swiftlint, xcodegen, etc.) assume
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/opt/homebrew/bin/brew shellenv)"
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile

# Git identity
git config --global user.name "Your Name"
git config --global user.email "you@example.com"

# GitHub CLI — fastest path to auth + clone without hand-managing a new SSH key
brew install gh
gh auth login          # choose: GitHub.com → HTTPS → Login with a web browser
gh repo clone <your-github-username>/TennisAnalyzer ~/TennisAnalyzer
```

At this point the repo is on the Mac and Xcode is fully licensed and ready — everything so far cost you a couple of minutes of billed time, not the usual first-run wait.

---

## 4. GUI-required steps (Screen Sharing)

Only these steps genuinely need the screen:

1. **Open Xcode → sign in with your Apple ID**: Xcode → Settings → Accounts → "+" → Apple ID. This creates your personal free signing team.
2. **Create the project**: File → New → Project → iOS → App.
   - Product Name: `TennisAnalyzer`
   - Team: your personal Apple ID team
   - Organization Identifier: the `com.<yourname>` you decided in step 0
   - Interface: SwiftUI · Language: Swift · Storage: None (no Core Data template — Phase 2 adds local history deliberately, per the playbook)
   - Save location: `~/TennisAnalyzer/ios-app/` (into the cloned repo — this replaces the placeholder `ios-app/README.md` directory contents; keep that README or fold its note into the project's top-level README)
3. **Add the camera usage description** (required — the app crashes on first camera access without it): target's **Info** tab → add key `Privacy - Camera Usage Description` (`NSCameraUsageDescription`) → value: `"TennisAnalyzer needs camera access to record your serve."`
4. **Build & run**: pick an iPhone Simulator in the scheme selector (e.g. iPhone 15), Cmd+R. A launching, blank SwiftUI app confirms the shell compiles — this is most of Phase 0's definition of done.
5. **Push the project** — back in a terminal (SSH is fine again from here):
   ```bash
   cd ~/TennisAnalyzer
   git add ios-app/
   git commit -m "Add Xcode project shell"
   git push
   ```

---

## 5. Known limitation: live camera capture needs a real device

The Simulator has no real camera — it can only import existing photos/video into its Photos app, not capture live video. That's sufficient to confirm the app shell and playback wiring compile and run (Phase 0's definition of done explicitly allows Simulator for this reason).

Testing **actual** camera capture needs a physical iPhone. Because the Mac mini is remote cloud hardware, you can't plug an iPhone into it over USB, and Xcode's wireless device pairing needs the iPhone and Mac on the same network — which a cloud Mac isn't, by default. Don't try to solve this in Phase 0; it's worth a deliberate look (e.g. a VPN bridging your phone's network to the Mac mini, or just doing real-device verification during a differently-provisioned session) once you're actually building the camera capture screen, not before.

---

## 6. Before ending the lease

Billing runs until you delete the instance — Scaleway doesn't stop the clock just because you're done for the day.

- [ ] `git push` everything
- [ ] Verify the push landed, from your Windows browser on GitHub
- [ ] Delete the Mac mini: console → Apple silicon → instance → Delete (or confirm auto-delete-after-24h was set at creation)
- [ ] Check off the completed items in [decisions.md](decisions.md)'s Mac lease TODO list
