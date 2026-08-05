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

Everything in this step needs no GUI. Run [`scripts/mac-lease-setup.sh`](../scripts/mac-lease-setup.sh) from this repo (it runs the same commands below and prompts for the few pieces of input), or paste the commands one at a time and check them against the expected output.

**Confirm Xcode and check its version**
```bash
xcodebuild -version
```
```
Xcode 16.x
Build version 16Xxxxxx
```
Exact version depends on whatever macOS release Scaleway currently defaults to — any recent Xcode 15/16 is fine. If instead you get `xcode-select: error: tool 'xcodebuild' requires Xcode`, the instance didn't provision Xcode correctly — worth a support ticket rather than trying to `xcode-select --install` it yourself (that only installs Command Line Tools, not full Xcode).

**Accept the Xcode license**
```bash
sudo xcodebuild -license accept
```
Prompts for **your macOS account password** (not your Apple ID) — nothing is echoed back as you type, that's normal. On success it returns silently to the prompt with no output at all. If it was already accepted (possible on some images), it also returns silently — either way, no output means success here.

**Run first-launch component install**
```bash
sudo xcodebuild -runFirstLaunch
```
May print a few lines like `Installing First Launch packages...` followed by package names, or print **nothing and return immediately** if Scaleway's image already has everything installed — both are fine. It should not ask you anything interactively; if it hangs, Ctrl-C and continue, it's not required for the Simulator to work.

**Confirm simulator runtimes**
```bash
xcrun simctl list devices available
```
```
== Devices ==
-- iOS 18.x --
    iPhone 16 Pro (XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX) (Shutdown)
    iPhone 16 (XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX) (Shutdown)
    ...
-- watchOS 11.x --
    ...
```
If the iOS section is missing or empty, a Simulator runtime isn't installed yet — fix it with `xcodebuild -downloadPlatform iOS` (takes a few minutes, needs network) before step 4.

**Install Homebrew**
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```
This is the noisiest command in the whole setup — expect a wall of `==> Downloading...` / `==> Installing...` lines over a minute or two. It will ask you to **press RETURN to continue** once near the start, and prompt for your **macOS account password** once (for `sudo` steps inside the installer). It ends with:
```
==> Installation successful!
...
==> Next steps:
- Run these commands in your terminal to add Homebrew to your PATH:
    echo >> /Users/<user>/.zprofile
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> /Users/<user>/.zprofile
    eval "$(/opt/homebrew/bin/brew shellenv)"
```
That's exactly what the next two commands below do, so you don't need to copy those lines from Homebrew's own output.

```bash
eval "$(/opt/homebrew/bin/brew shellenv)"
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
```
No output from either. Sanity-check it worked with `brew --version` → `Homebrew 4.x.x`.

**Git identity**
```bash
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```
No output. Verify with `git config --global --list` if you want to double check.

**GitHub CLI — install, auth, clone**
```bash
brew install gh
```
Similar `==> Downloading` / `==> Installing gh` noise, ending with something like:
```
🍺  /opt/homebrew/Cellar/gh/2.x.x: 148 files, 38.7MB
```

```bash
gh auth login
```
Fully interactive — answer the prompts:
```
? What account do you want to log into? GitHub.com
? What is your preferred protocol for Git operations on this host? HTTPS
? Authenticate Git with your GitHub credentials? Yes
? How would you like to authenticate GitHub CLI? Login with a web browser

! First copy your one-time code: XXXX-XXXX
Press Enter to open github.com in your browser...
```
Copy the code, open the printed URL from **your own browser** (not necessarily on the Mac — any device works), paste the code, authorize. The terminal then finishes with:
```
✓ Authentication complete.
✓ Configured git protocol
✓ Logged in as ElvisOkereke
```

```bash
gh repo clone ElvisOkereke/TennisAnalyzer ~/TennisAnalyzer
```
```
Cloning into 'TennisAnalyzer'...
remote: Enumerating objects: ...
remote: Counting objects: 100% ...
Receiving objects: 100% ...
Resolving deltas: 100% ...
```
Confirm it worked with `ls ~/TennisAnalyzer` → should list `README.md`, `LICENSE`, `docs/`, `ios-app/`, `python/`, `scripts/`, `.github/`.

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
   `git add` prints nothing. `git commit` prints a summary like `[main abc1234] Add Xcode project shell` followed by a list of files changed/created (there will be a lot — Xcode projects generate many small files). `git push` ends with something like:
   ```
   To https://github.com/ElvisOkereke/TennisAnalyzer.git
      60781a9..abc1234  main -> main
   ```
   If `git push` instead asks for a username/password interactively and rejects them, `gh auth login` didn't wire up git credentials — run `gh auth setup-git` and retry.

---

## 5. Known limitation: live camera capture needs a real device

The Simulator has no real camera — it can only import existing photos/video into its Photos app, not capture live video. That's sufficient to confirm the app shell and playback wiring compile and run (Phase 0's definition of done explicitly allows Simulator for this reason).

Testing **actual** camera capture needs a physical iPhone, and there's a hard constraint here, not just an inconvenient one: Xcode's device pairing/trust handshake is USB-based even for later wireless debugging — a device that has never been physically connected via cable can't be wirelessly paired, full stop. A VPN bridging the phone's network to the Mac mini gives IP connectivity but does **not** solve this; it was wrongly floated here as an option and doesn't actually work.

That leaves two real options once real-device testing is wanted:
1. **Enroll in the Apple Developer Program ($99/yr) and use TestFlight.** This is the only path that works with a fully-remote Mac — TestFlight installs happen entirely over the internet, no USB/local-network pairing ever needed. This is the same enrollment originally slated for Phase 6 (App Store/TestFlight); doing it earlier is a cost/timing tradeoff, not a technical requirement.
2. **One-time USB pairing on a different, physically-accessible Mac** (yours, borrowed, a library/coworking space) — but note this ties future real-device debugging to *that* Mac, not the Scaleway lease.

Phase 0's definition of done explicitly allows Simulator-only verification (seed a clip via `xcrun simctl addmedia`, confirm playback), so don't block on this — it's an opportunistic follow-up, not a Phase 0 requirement.

---

## 6. Before ending the lease

Billing runs until you delete the instance — Scaleway doesn't stop the clock just because you're done for the day.

- [ ] `git push` everything
- [ ] Verify the push landed, from your Windows browser on GitHub
- [ ] Delete the Mac mini: console → Apple silicon → instance → Delete (or confirm auto-delete-after-24h was set at creation)
- [ ] Check off the completed items in [decisions.md](decisions.md)'s Mac lease TODO list
