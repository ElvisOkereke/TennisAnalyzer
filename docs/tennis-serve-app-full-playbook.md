# TennisAnalyzer — Full Development & Career Playbook

A complete reference for building this from first prototype to a launched product, plus how to turn the work itself into a case for hiring you as an AI engineer. Organized so you can work top to bottom by phase, or jump to a topic (cost, architecture, ML lifecycle, career) as needed.

**How to use this doc:** each phase in §2 has a definition of done. Don't start a phase until the previous one's is met — the tradeoff tables in §3 exist so you can make each phase's technology decisions once, deliberately, instead of re-deciding under pressure later.

---

## 1. Feature Inventory (full scope, tagged by phase)

| Feature | First appears | Depends on |
|---|---|---|
| Video capture/import | MVP | — |
| Manual joint marking (fallback) | MVP | — |
| Auto pose detection | Phase 2 | On-device pose model |
| Auto phase detection (trophy/contact/follow-through) | Phase 2 | Pose keypoints |
| Mechanics metrics (knee bend, elbow angle, contact height) | MVP (manual) → Phase 2 (auto) | Phase marks |
| Rule-based feedback | MVP | Metrics |
| On-device local history | Phase 2 | — |
| Ball detection | Phase 3a | Object detection model |
| Ball tracking/trajectory | Phase 3a | Ball detection + frame-to-frame tracker |
| Court calibration | Phase 3b | User input (tap points) |
| Speed estimate | Phase 3b | Ball tracking + calibration |
| In/out landing detection | Phase 3b | Ball tracking + calibration |
| Serve-type heuristic (flat/slice/kick) | Phase 3c | Pose + ball trajectory features |
| Data collection/labeling pipeline | Phase 3a (start), ongoing | — |
| Fine-tuned ball detector | Phase 4 | Labeled data |
| Trained serve-type classifier | Phase 4 | Labeled data |
| Accounts + cloud sync | Phase 4 | Backend |
| Cross-session trends | Phase 4 | Accounts + persisted history |
| Coach sharing/export | Phase 5 | Accounts |
| Dual-camera fusion | Phase 5 | — |
| Ghost-overlay comparison vs. reference serve | Phase 5 | — |
| Full public launch (app store, marketing site, support) | Phase 6 | Everything above stable |
| Full-match capture mode (whole-court, elevated) | Phase 7 | Everything through Phase 4 |
| Whole-court landing overlay (both sides) | Phase 7 | Court calibration (Phase 3b), extended to full court |
| Rally/shot segmentation | Phase 7 | Ball tracking (Phase 3a) |
| Shot attribution (which player hit which shot) | Phase 7 | Rally/shot segmentation |

This table is the single source of truth for "what phase does X belong to" — refer back to it instead of re-litigating sequencing per feature.

---

## 2. Phased Development Plan

Each phase lists: goal, features, definition of done, and a rough solo/part-time time estimate. Estimates assume you're learning some of this as you go (which is the point, per §11) — treat them as order-of-magnitude, not commitments.

### Phase 0 — Foundations (1–2 weeks)
**Goal:** environment, repo, and skeleton app exist; you've made the big framework decisions once.
- Set up the dev environment split (§3.7): Windows as primary machine, first Scaleway Mac lease for Xcode/repo scaffolding.
- Set up native iOS app shell (Swift/SwiftUI, per §3.1) with camera capture and playback (AVFoundation) — done during that first Mac lease.
- Repo structure, CI skeleton (lint/test on push), basic crash reporting wired in — the non-Xcode parts of this can be done from Windows before or after the Mac lease.
- Decide and document: mobile framework, on-device ML approach, backend (deferred but decided).
**Definition of done:** you can record a clip on a real device (or Simulator) and play it back in your own app shell.

### Phase 1 — MVP: manual mechanics (1–2 weeks)
**Goal:** the smallest end-to-end useful loop, no AI required yet, to validate the mechanics/feedback logic before automating anything.
- Manual joint marking on a paused frame (trophy + contact).
- Geometry engine: knee bend angle, elbow angle at contact, contact-height ratio.
- Rule-based feedback engine (thresholds from your earlier plan).
- On-device only, no accounts.
**Definition of done:** a stranger can mark their own clip without your help and get feedback that isn't obviously wrong (validate per §10's testing approach).

### Phase 2 — Automatic mechanics (3–5 weeks)
**Goal:** everything from Phase 1, with zero manual marking.
- Integrate an on-device pose model (§3.2) running per-frame on the recorded clip.
- Build the phase detector: heuristics on joint-velocity peaks/zero-crossings to auto-locate trophy/contact/follow-through.
- Re-point the existing geometry/feedback engines (unchanged from Phase 1) at auto-detected keypoints instead of manual ones.
- Local history (SQLite/WatermelonDB) so sessions persist.
**Definition of done:** record a clip, do nothing else, get mechanics feedback in a few seconds. This is your first genuinely demoable AI milestone.

### Phase 3a — Ball detection & tracking (1.5–2 weeks)
**Goal:** the ball is visibly detected and tracked — the first demoable win of Phase 3, split out so you're not waiting 5-8 weeks for your next "it works" moment after Phase 2.
- Bootstrap ball detection with a generic small object detector (COCO "sports ball" class or similar), deployed via Core ML.
- Frame-to-frame tracker (constant-velocity filter, upgrade to Kalman if needed) to smooth detections into a trajectory.
- **Start data collection now** (§11): pull court-view footage from YouTube (professional and amateur matches/practice) plus your own recordings, and begin labeling ball bounding boxes as you go — this is the long pole for Phase 4, so start on day one of Phase 3, not at the end.
**Definition of done:** record or import a clip, see the ball's trajectory drawn over the video automatically.

### Phase 3b — Court calibration & physical stats (2–3 weeks)
**Goal:** turn the tracked trajectory into real-world numbers.
- Court calibration flow (tap 4 known points once per setup) → homography → pixel-to-real-world conversion.
- Bounce/landing detection, in/out determination, speed estimate (with a visible confidence indicator).
**Definition of done:** speed and an in/out call appear automatically per serve, visibly marked as estimates.

### Phase 3c — Serve-type heuristic (1.5–2.5 weeks)
**Goal:** classify serve type using the pose (Phase 2) and trajectory (Phase 3a/b) signals already built.
- Serve-type heuristic from contact-arm path + toss position + post-bounce trajectory shape.
**Definition of done:** a serve-type guess appears automatically per serve, visibly marked as an estimate, on top of the ball stats from 3b — and the labeled dataset from 3a/3b is large and diverse enough to make Phase 4 possible.

### Phase 4 — Real models + platform (6–10 weeks)
**Goal:** replace heuristics with trained models; add the backend needed for history to survive a device change.
- Fine-tune the ball detector on your labeled dataset — expect this to be the single biggest accuracy jump in the whole project.
- Train a serve-type classifier on pose+trajectory features from labeled clips.
- Backend: accounts + cloud sync (Supabase or Firebase, not custom auth) — see §3.5.
- Cross-session trend views (speed over time, serve-type mix, in/out rate).
**Definition of done:** serve-type and ball-detection accuracy visibly beats the Phase 3 heuristics on a held-out set of your labeled clips (see §11.4 for how to measure this), and a user's history survives switching devices.

### Phase 5 — Growth features (4–8 weeks, can run partly in parallel with Phase 4)
**Goal:** features that matter once you have real users, not before.
- Coach sharing/export (link or PDF report).
- Dual-camera capture and fusion, if single-camera accuracy has plateaued.
- Ghost-overlay comparison against a reference serve.
**Definition of done:** a coach can use the app with a student without you in the room to explain it.

### Phase 6 — Full launch (2–4 weeks of dedicated launch work, ongoing after)
**Goal:** public availability with the operational basics in place.
- App store submission (iOS App Store) — review guidelines, screenshots, privacy disclosures. (Google Play only applies if/when you build the Android port — see §3.1.)
- Marketing site / landing page, support channel (even just an email or a form).
- Monitoring, crash reporting, and a basic on-call habit for yourself (§9).
- Privacy policy and terms — required for app store approval and for handling any video/personal data.
**Definition of done:** someone you've never met can find, install, and use the app without you doing anything manually on their behalf.

**Total rough estimate, solo/part-time, Phase 0 through Phase 4 (a genuinely complete, differentiated product):** roughly 4–7 months. Phase 5/6 are open-ended and demand-driven — don't block calling this "a real project" on reaching them.

### Phase 7 — Full match mode (future vision, not yet scoped/estimated)
**Goal:** track a full match rather than a single serve — ball landing overlay and shot detection for both players, even the one on the far side of the court.

**This is a different capture mode, not an extension of Phases 0-4.** Mechanics analysis needs a close, side-on, single-player view; full-match tracking needs a wide, elevated, whole-court view. Those two trade off against each other on a single non-zooming camera, so this becomes its own mode with its own capture guidance, not a feature toggle bolted onto Phase 4.

- **Capture:** single camera, elevated, mounted behind one baseline or on a fence pole, wide FOV covering the full court — comparable to how SwingVision and similar products already do this; worth studying as prior art before designing from scratch.
- **Whole-court calibration:** extend the homography approach already built in Phase 3b to the full court rather than just the near-side landing zone — same technique, wider scope.
- **Rally/shot segmentation:** detect individual shot events (bounces + contacts) across a continuous rally, not just one serve per clip — a genuinely new problem, not present in Phases 0-4.
- **Shot attribution:** determine which player hit each shot — needs coarse two-player position tracking, not the per-player joint-level pose Phase 2 builds.
- **Known hard limit:** far-side ball/player resolution is a physical constraint (a tennis ball is a handful of pixels at ~78 feet on a phone camera), not something a better model fixes — scope far-side analysis to trajectory/landing detection, not mechanics detail.

**Why parked for now:** it doesn't block or change any Phase 0-4 decision, and attempting it before Phase 4 lands would mean building two capture pipelines at once. One cheap thing to do now: when sourcing YouTube footage for the ball detector (§11.2), include some wide/full-court rally shots alongside serve-focused clips, so this phase doesn't start its dataset from zero.

---

## 3. Build Options & Tradeoffs (the decisions worth making deliberately)

### 3.1 Mobile framework

**Decision: native iOS (Swift + Vision + Core ML + AVFoundation), single platform.** This project's differentiator is on-device CV/ML depth (§12) — a cross-platform bridge layer (RN's `react-native-vision-camera` frame processors, TFLite bindings) is overhead sitting directly on top of the part of the app meant to demonstrate that depth. Apple's Vision framework provides body-pose detection as a first-party API — no bridge, no bundled pose model, tuned for the Neural Engine on every supported device. The cost is platform breadth, not feature depth, and breadth is the right thing to cut for a portfolio-first project — the same logic as §12's "cut sophistication before you cut 'the app works end to end.'"

| Option | Pros | Cons | Verdict |
|---|---|---|---|
| Native iOS (Swift + Vision + Core ML) | No bridge layer for the CV/ML work; first-party pose API (`VNDetectHumanBodyPoseRequest`) tuned for the Apple Neural Engine; small, consistent device fleet to test against | iOS only — no Android reach; Swift/Vision/Core ML is new territory | **Chosen** |
| React Native (bare/custom dev client) | One codebase, huge ecosystem, `react-native-vision-camera` for frame-level camera access | On-device ML bindings (TFLite/MediaPipe) less mature than native; the bridge layer sits directly on top of the app's differentiating work | Reasonable if Android reach ever matters more than build depth |
| Flutter | Single codebase, strong performance | Smaller selection of maintained custom-model ML packages | Weaker fit than RN for this specifically — not worth it here |
| Native Android (Kotlin + ML Kit/CameraX) | Best possible ML+camera integration on Android | A second full native codebase | Only worth building later, as a deliberate port — see below |

**Why Android tooling lags for this use case:** it's not that Google's on-device ML APIs are bad — ML Kit's Pose Detection and MediaPipe Tasks are genuinely competitive with Vision. The gap is hardware and fleet fragmentation. Apple ships one vendor's silicon with a Neural Engine in every device since the iPhone 8/XS generation, so Core ML/Vision inference is fast and consistent everywhere Apple supports it. Android spans dozens of chipset vendors (Qualcomm, MediaTek, Samsung, etc.) with wildly inconsistent NPU presence and NNAPI driver quality — many mid/budget devices have no dedicated NPU at all, so inference silently falls back to slower CPU/GPU. That's exactly the "device fleet variability" §9 already flags as a scaling risk — going iOS-only for now sidesteps it rather than solving it.

**Cross-platform later, if you want it:** yes — this is a normal path, not a rewrite. The genuinely hard parts of this project (geometry engine, phase-detection heuristics, feature engineering, the trained ball detector and serve-type classifier) are platform-agnostic logic and model weights. A model trained once (PyTorch/TF) exports to both Core ML (iOS) and TFLite (Android) from the same training pipeline in §11. Porting to Android later means writing a new capture/inference shell in Kotlin + CameraX + ML Kit or MediaPipe Tasks Pose Landmarker, and re-pointing it at the same metrics/feedback/classifier logic — bounded, well-scoped work you'd do once the iOS version has proven the concept, not a parallel 2x cost paid upfront while you're still learning the CV fundamentals.

### 3.2 Pose estimation model

**Decision: Apple's Vision framework (`VNDetectHumanBodyPoseRequest`), first-party, no bundled model.** Since §3.1 chose native iOS, there's no bridge layer to reason about — Vision ships built into iOS, is tuned for the Neural Engine, and needs no conversion/quantization step of its own. This also drops "on-device pose estimation" from Low-Medium to Low in §7's complexity table — the integration tax there was specifically the RN/mobile bridging work, which no longer applies.

| Option | Accuracy on fast/occluded motion | Integration effort | Notes |
|---|---|---|---|
| Vision framework body pose (`VNDetectHumanBodyPoseRequest`) | Moderate-good | Low (first-party, no bundled model) | **Chosen** — default start on native iOS |
| MediaPipe Tasks Pose Landmarker | Similar to BlazePose, more keypoints | Low | Fallback if Vision loses the tossing arm on fast motion; also the natural shared choice if/when you port to Android (§3.1) |
| Server-side model | Highest, but requires a round trip | High (needs backend + GPU cost per session) | Not worth it unless on-device accuracy is proven to be the actual bottleneck |

### 3.3 Ball detection model

| Option | Pros | Cons |
|---|---|---|
| Generic detector (COCO "sports ball" class, e.g., a small YOLO variant) | Zero training needed, fast to integrate | Not tuned for a small, fast, motion-blurred tennis ball specifically — expect visible misses |
| Fine-tuned small detector (YOLOv8n or similar, fine-tuned on your labeled data) | Meaningfully better accuracy on the actual use case | Requires the labeling pipeline in §11 before it's possible |

Bootstrap with the generic option in Phase 3, budget the fine-tune as a first-class Phase 4 deliverable rather than "polish." On native iOS (§3.1), both stages deploy through **Core ML** — export the PyTorch-trained model via `coremltools` rather than converting to TFLite; the training pipeline in §11 is otherwise unchanged, and the same PyTorch weights can also export to TFLite later if you port to Android.

### 3.4 Serve-type classification

| Option | Effort | Accuracy ceiling |
|---|---|---|
| Rule-based heuristic (contact-arm path, toss position, bounce shape) | Low | Limited — proxies for spin, not spin itself |
| Trained classifier (small model on pose+trajectory features) | Medium, requires labeled data | Meaningfully better, still bounded by 2D-video limits on measuring true spin |
| Specialized hardware/high-frame-rate capture for real spin measurement | High | Only worth it if the product truly needs precise spin, not just a type label |

### 3.5 Backend & storage

**Decision: Supabase**, brought in at Phase 4.

| Option | Pros | Cons |
|---|---|---|
| None (client-only, through Phase 3) | No infra to run/pay for, best privacy story | No cross-device history |
| Supabase (Postgres + auth + storage) | One vendor, generous free tier, SQL if you want it | Still a dependency to manage |
| Firebase (Firestore + auth + storage) | Same category of convenience, document model | Not chosen — Supabase covers the same needs |
| Custom backend (Node/Django/etc. + your own DB) | Full control | Meaningfully more work for no clear benefit at this stage — avoid until you have a specific reason |

Stay client-only through Phase 3; bring in Supabase at Phase 4.

### 3.6 Hosting (for any web landing page / marketing site, separate from the app itself)
Static hosting (Vercel, Netlify, Cloudflare Pages) — no reason to run your own server for a marketing page.

### 3.7 Development environment: Windows (primary) + cloud Mac (on demand)

**Decision: Windows stays the primary dev machine for everything that doesn't require Apple frameworks; a rented cloud Mac mini (Scaleway, M2-M tier — 16GB RAM, pay-as-you-go, ~€0.17/hr) is leased in short, batched blocks only for the work that genuinely requires macOS.** This isn't a compromise — most of this project's real complexity (per §7) is portable logic and ML work that has nothing to do with Xcode, so there's no reason to pay for Mac time while doing it.

**Stays on Windows, all the time:**
- Geometry engine, phase-detection heuristics, tracker, homography math, serve-type feature engineering — prototyped and unit-tested in Python against sample/exported data, ported to Swift only once the logic is validated.
- Ball detector fine-tuning and serve-type classifier training (§11.3) — fully portable, no Mac dependency at all.
- Core ML model conversion via `coremltools` (works under WSL) — conversion happens on Windows; only *validating* the converted model's predictions requires macOS.
- Data collection & labeling (§11.2), repo structure, CI config, docs, Supabase/Sentry account setup.

**Requires a Mac lease:**
- Xcode project setup, SwiftUI screens, AVFoundation camera integration.
- Vision framework (`VNDetectHumanBodyPoseRequest`) integration and testing — no way to run this off Apple hardware.
- Core ML runtime integration/validation on Simulator or device.
- Core Data/GRDB wiring, Instruments profiling (§6).
- TestFlight and App Store Connect submission (Phase 6).

**Efficient workflow for the split:**
1. Do all portable work on Windows first, per phase — validate the algorithm/model logic against real data before touching Xcode at all.
2. Keep a setup script in the repo (Xcode CLI tools, clone, signing cert import, dependency install) so a fresh Mac lease is provisioned in minutes. Scaleway's Apple-silicon tier has no confirmed snapshot/image feature, so treat every lease as a clean machine.
3. Batch Mac work into single leases spanning a few consecutive days rather than daily on/off — Apple's licensing terms impose a 24-hour minimum lease on Scaleway's macOS tier regardless of session length, so short daily sessions waste money for no benefit.
4. On each Mac lease: pull the latest Windows-validated logic, port it into Swift, wire it into the app (UI/camera/Vision/Core ML), test on Simulator/device, profile if needed, then commit and push everything back to the repo before the lease ends.
5. Delete the instance (or let auto-delete-after-24h fire) at the end of each lease — don't leave it running between work blocks.
6. Reserve the biggest, least-interruptible Mac blocks for the things that are genuinely hard to context-switch out of: initial Xcode project scaffolding (Phase 0), Vision/AVFoundation integration (Phase 2), and App Store submission (Phase 6).

**Cost impact:** narrowing Mac-only work to integration/testing/signing rather than full development means Mac lease time is a small fraction of total project time. At the M2-M tier (~€0.17/hr, roughly $0.25 CAD/hr), even a generous estimate of 150–200 total lease-hours across Phase 0–4 (batched into roughly 8–10 multi-day leases) lands around **$40–50 CAD total** for the entire project's Mac access — see §8.

---

## 4. Architecture (target, Phase 4+)

```
┌─────────────────────────── iOS app (Swift) ───────────────────────┐
│ Camera (AVFoundation, AVCaptureVideoDataOutput)                    │
│   │ per-frame callback                                            │
│   ▼                                                                │
│ Frame processor                                                    │
│   ├─► Pose (Vision: VNDetectHumanBodyPoseRequest) → keypoints      │
│   └─► Ball detector (Core ML)     → bbox + confidence             │
│   ▼                                                                │
│ Tracker/smoother (per-object)                                     │
│   ▼                                                                │
│ Phase detector · Court-calibration transform                      │
│   ▼                                                                │
│ Metrics engine · Ball-stats engine · Serve-type engine             │
│   ▼                                                                │
│ Feedback/rule engine                                               │
│   ▼                                                                │
│ Local DB (Core Data / SQLite via GRDB) ──► UI                      │
└──────────────────────────┬──────────────────────────────────────┘
                            │ sync (opt-in, derived data by default —
                            │ not raw video, unless user explicitly opts in)
                            ▼
              ┌───────────────────────────┐
              │ Backend (Supabase/Firebase)│
              │  - Auth                    │
              │  - Sessions/metrics/stats  │
              │  - Optional video storage  │
              └───────────────────────────┘
                            │
                            ▼
              Trend queries, coach sharing links

┌──────────── Offline model-training pipeline (your machine/cloud) ────────────┐
│ Labeled data (CVAT/Roboflow exports) → training (PyTorch/TF) →                │
│ evaluation → export/quantize (Core ML) → bundle into next app release         │
└────────────────────────────────────────────────────────────────────────────┘
```

Two pipelines, deliberately separate: the **on-device inference pipeline** (top) that runs in the shipped app, and the **offline training pipeline** (bottom) that produces the models the app bundles. Keeping these decoupled is what makes model updates a release-cycle concern rather than something that needs live infrastructure.

---

## 5. User Experience

### Core UX principles
- **Automatic first, manual as fallback.** Every automated step (pose, phase detection, ball tracking) should have a visible, low-friction manual correction path — auto-detection will sometimes be wrong, and forcing a re-record is worse than letting the user nudge a frame or point.
- **Show confidence, don't hide it.** Speed estimates, serve-type guesses, and low-confidence keypoints should look visibly different from high-confidence ones (a range, a tag, a muted color) — presenting an estimate as a precise number is a trust problem waiting to happen.
- **Cap feedback at 2–3 items per serve.** More than that reads as noise, not coaching.
- **One-time setup costs should feel one-time.** Court calibration should persist per camera setup, not be repeated every session.

### Key flows to design explicitly
1. First-run: camera permission, brief "film side-on" guidance, optional court-calibration walkthrough.
2. Record/import → automatic processing (with a progress indicator honest about what's happening — "detecting your pose," "tracking the ball" — not a generic spinner).
3. Results: mechanics + ball stats + serve type together, prioritized feedback, raw numbers available but not front-and-center.
4. History: session list, per-session drill-down, trend view once Phase 4 lands.
5. Correction flow: tap to nudge a mis-detected phase frame or ball position, without restarting the whole analysis.

---

## 6. Performance

| Concern | Target/approach |
|---|---|
| On-device inference latency | Aim to process a several-second clip in low single-digit seconds on a mid-range (not just flagship) iPhone — test on an older supported model early, not just your own phone |
| Frame rate for capture | 60fps minimum if the device supports it, 120fps (slow-mo) preferred for ball-speed accuracy near contact |
| Battery/thermal | Running two models (pose + ball detector) per frame is real compute load — profile battery drain on a real recording+processing session, not just in short bursts |
| Graceful degradation | If a device can't keep up, drop to lower-frequency pose sampling or skip live preview overlays rather than freezing the UI |
| Offline-first | All core analysis should work with no network connection — sync (Phase 4+) is additive, never a blocker to using the app |

---

## 7. Complexity Assessment

| Component | Complexity | Why |
|---|---|---|
| Video capture/playback | Low | Native platform APIs, well-trodden |
| Manual marking UI | Low | Straightforward interaction design |
| On-device pose estimation | Low | First-party Vision framework API on native iOS (§3.2) — no bridging layer, no bundled model to convert |
| Phase detection heuristics | Medium | No off-the-shelf solution; requires iteration against real footage |
| Ball detection (generic) | Medium | Integration is easy, tuning expectations (see §2 reality check) is the real work |
| Ball detection (fine-tuned) | High | Full ML pipeline: labeling, training, evaluation, deployment |
| Court calibration/homography | Medium | Well-understood math (homography is standard CV), UX is the harder part |
| Serve-type heuristic | Medium | Feature engineering from noisy signals |
| Serve-type trained classifier | High | Needs a real labeled dataset and a training/eval loop |
| Accounts/cloud sync | Low-Medium | Managed backend (Supabase/Firebase) absorbs most of the hard parts |
| Trend dashboards | Low | Standard charting once data exists |
| Dual-camera fusion | High | Real computer-vision problem (multi-view calibration/fusion) |

Use this table to sanity-check your own time estimates per phase — if a "Medium" task is taking "High" effort, that's a signal to simplify scope rather than push through.

---

## 8. Cost

Rough costs at different stages — actuals will vary by region/vendor pricing changes, treat as planning-order-of-magnitude.

| Stage | Main costs | Rough range |
|---|---|---|
| Phase 0–2 (prototype, solo) | Dev time only; free tiers cover everything (Xcode, on-device Vision/Core ML, local storage) | $0 out-of-pocket beyond a developer account fee |
| Apple developer account | Annual | ~$99/yr (Google Play's ~$25 one-time only applies if/when you build the Android port, §3.1) |
| Cloud Mac access (Scaleway, §3.7) | Pay-as-you-go Mac mini leases, batched to cover only the Xcode-required work | ~$40–50 CAD total across Phase 0–4, given how narrow the actual Mac-only scope is |
| Phase 3 (data labeling tooling) | CVAT (free, self-hosted) or Roboflow (free tier, paid tiers if dataset grows) | $0–50/mo depending on dataset size |
| Phase 4 (model training compute) | Cloud GPU time (if not training locally) for fine-tuning detector/classifier | $20–200 for a training run on a modest dataset, cloud GPU by the hour |
| Phase 4 (backend) | Supabase/Firebase free tier covers early usage; paid tiers scale with users/storage | $0 early, tens to low hundreds/mo as usage grows |
| Phase 6 (launch) | App store fees (above), possibly a marketing site domain/hosting | ~$10–20/yr domain, hosting often free tier |
| Ongoing (post-launch) | Backend scaling, any paid API usage, support tooling | Scales with users — budget to revisit at real usage milestones, not up front |

**Key point:** this project is buildable through Phase 4 on free/near-free tooling plus modest one-time costs. Don't let cost anxiety drive premature infrastructure decisions — the free tiers of Supabase/Firebase and CVAT/Roboflow are generous enough to cover a genuinely complete solo project. This also means **not owning a Mac isn't a real barrier**: with the Windows-primary, cloud-Mac-on-demand workflow in §3.7, the platform decision in §3.1 doesn't require a Mac purchase at all — a few tens of dollars in batched Scaleway leases covers it.

---

## 9. Scalability & DevOps

### Scalability considerations
- **Device fleet variability** is smaller than it would be cross-platform, but not zero — iPhones from the last several generations still vary meaningfully in Neural Engine performance; test on an older supported iPhone, not just your own, before wide release. (This is one of the concrete payoffs of the native-iOS decision in §3.1 — Android's chipset fragmentation would have made this a much bigger problem.)
- **Backend scaling** (Phase 4+) is mostly handled by your managed provider (Supabase/Firebase) at the user counts this kind of app is likely to see early on — don't pre-optimize for scale you don't have.
- **Model retraining pipeline** should scale with your labeled dataset, not your user count — plan for periodic retraining (e.g., after every meaningful batch of new labeled data) rather than continuous retraining.

### DevOps / MLOps to have in place before/at launch
| Practice | Why | When |
|---|---|---|
| CI (lint, test, build) on every push | Catch breakage before it reaches a device | Phase 0 |
| Crash reporting (e.g., Sentry) | You need to know when the app breaks on devices you don't own | Phase 1–2 |
| Model versioning | Know exactly which model version produced which result, especially once you're iterating on the ball detector/classifier | Phase 3–4 |
| Basic analytics (usage, not intrusive) | Understand what's actually used before investing in Phase 5 features | Phase 2–3 |
| App store release pipeline (fastlane or similar) | Manual store submissions get old fast once you're iterating | Phase 4–6 |
| Privacy policy + data handling docs | Required for app store approval, and just good practice given the video/health-adjacent data | Before Phase 6 |
| A lightweight on-call habit for yourself | Someone will hit a crash after launch; know how you'll find out and respond | Phase 6 |

---

## 10. Testing & Validation (carried through every phase)

- **Geometry unit tests** for every angle/ratio formula — this is the highest-value, cheapest testing you can do, since silent math errors are otherwise invisible.
- **Ground-truth comparison**: for mechanics, manually estimate angles on a set of real clips and compare against the app's output before trusting thresholds (as in the earlier plan).
- **Model evaluation**: once you have trained models (Phase 4), hold out a labeled test set the model never trained on, and track precision/recall (ball detection) and accuracy/confusion matrix (serve-type classification) release over release — this is also a great source of concrete numbers for your portfolio (§12).
- **Real-device testing**: performance and UX testing on actual mid-range hardware, not just your dev phone.
- **User testing on feedback copy**: get real players/coaches reacting to the wording, not just the numbers — this was true in the manual-marking MVP and remains true here.

---

## 11. AI Model Development, End to End

This is the part of the project most worth doing carefully — it's also the part most valuable for §12.

### 11.1 Problem framing
You have two genuinely distinct ML problems:
1. **Ball detection** — an object detection problem (localize a small object in a frame).
2. **Serve-type classification** — a classification problem over engineered features (pose + trajectory), not a raw end-to-end video model — keep it this way for as long as possible; a feature-based classifier is dramatically cheaper to build, debug, and explain than an end-to-end deep model, and is a better starting point even if you revisit that decision later.

### 11.2 Data collection & labeling
**Primary source: YouTube match/practice footage (professional and amateur), court-view angles, plus your own recordings** — this solves the volume/diversity problem a solo dev usually can't solve alone: different courts, lighting, players, and skill levels, without having to film all of it yourself.

Two things to watch with YouTube-sourced footage:
- **Camera-angle mismatch.** Broadcast footage is typically shot from an elevated, wide, corner-of-court angle — different from the side-on phone-on-tripod angle your app's own first-run guidance tells users to film with (§5). That's fine, even helpful, for the ball detector (it just needs to see a small, fast, motion-blurred ball under varied conditions) and for building a large serve-type dataset — but keep shooting your own side-on footage too, so the phase-detection heuristics and pose thresholds stay tuned to the angle real users will actually use.
- **Use for training, not redistribution.** Downloading footage for your own model training is the common, low-risk case (this is how most sports-analytics research datasets get built) — but if you act on §12's "open-source the dataset" idea later, release only your labels/annotations and trained weights, not re-hosted copies of the source clips, since those are someone else's broadcast footage.

- Collect footage across varied conditions early: different courts, lighting, camera distances, skill levels — a dataset that's all your own serves on your own court will overfit to that setup.
- Label ball bounding boxes with CVAT or Roboflow (free tiers are sufficient to start); label serve type by eye while reviewing footage.
- Track dataset size and class balance explicitly (e.g., if you have 10x more flat serves than kick serves, your classifier will reflect that imbalance) — this is a concrete, quotable thing to manage and later describe.

### 11.3 Training
- **Ball detector**: fine-tune a small pretrained detector (e.g., a YOLOv8-nano-class model) on your labeled set rather than training from scratch — transfer learning from a model already good at general object detection is both faster and more likely to work with a modest dataset.
- **Serve-type classifier**: start with a simple, interpretable model (logistic regression or a small decision tree/gradient-boosted model on your engineered features) before reaching for a neural network — simple models are easier to debug when accuracy is disappointing, and "why did it get this wrong" is answerable.

### 11.4 Evaluation
- Hold out a test set the model never sees during training or hyperparameter tuning.
- Ball detector: precision/recall, and specifically check performance near contact (motion blur) since that's the hardest and most important region.
- Serve-type classifier: accuracy plus a confusion matrix — pay attention to which types get confused with which, not just the overall number.
- Compare every trained model against the heuristic it's replacing on the same test set — "the model beats the heuristic by X points" is both the bar for shipping it and a genuinely good portfolio artifact.

### 11.5 Optimization for on-device deployment
- Convert trained models to Core ML (via `coremltools`) — the same PyTorch/TF weights can also export to TensorFlow Lite later if you build the Android port (§3.1).
- Quantize (e.g., to int8) to shrink model size and speed up inference — measure the accuracy cost of quantization explicitly rather than assuming it's negligible.
- Benchmark inference time on real target devices, not just your training machine.

### 11.6 Deployment & monitoring
- Bundle models into the app release (Phase 4+) — no live model-serving infrastructure needed given the on-device-first architecture.
- Version models explicitly (see §9) so you can correlate user-reported issues with a specific model version.
- Log prediction confidence distributions (not raw video, per your privacy stance) to spot drift — e.g., if confidence scores start trending down, that's a signal real-world conditions have shifted from your training data.

### 11.7 Retraining cadence
- Retrain when you've accumulated a meaningfully larger/more diverse labeled set, or when monitoring (§11.6) suggests drift — not on a fixed calendar schedule disconnected from actual data growth.

---

## 12. Using This Project to Market Yourself as an AI Engineer

### Why this project is a genuinely strong portfolio piece
Most AI-engineer portfolios right now are thin LLM wrappers — a chatbot UI over an API call. This project is differentiated because it demonstrates things a wrapper doesn't:
- **A real, non-trivial CV problem** (small/fast object detection, pose estimation) rather than calling someone else's foundation model API.
- **On-device deployment** — a genuinely different (and less commonly demonstrated) skill set than server-side inference: model conversion, quantization, performance-constrained engineering.
- **A full ML lifecycle you actually ran**: data collection, labeling, training, evaluation, deployment, monitoring — the whole loop, not just a Jupyter notebook.
- **Product thinking alongside ML**: you made real tradeoffs (heuristic-first, confidence display, privacy-by-default) instead of just chasing a metric.
- **A mobile app that ships** — most portfolio ML projects never leave a notebook or a Streamlit demo; an installable app is a materially higher bar and reads as such.

### What to build, in order of leverage for a job search
1. **A finished, working thing beats an ambitious, unfinished thing.** If you have to cut scope to actually ship, cut ball-tracking sophistication before you cut "the app works end to end." A demoable Phase 2 (automatic mechanics) is worth more in an interview than a half-built Phase 4.
2. **Public artifacts, not just private code:**
   - A public GitHub repo with a genuinely good README (problem statement, architecture diagram, what you tried that didn't work and why — this last part signals real engineering more than a list of what worked).
   - A short demo video (60–90 seconds) showing the app actually working on a real serve — this is the single highest-conversion artifact for a portfolio; most reviewers will watch a video before reading code.
   - A written case study/blog post walking through one hard problem you solved (e.g., "why generic ball detectors fail on tennis balls, and how I fixed it" or "building a phase-detection heuristic without labeled data") — depth on one real problem beats a shallow tour of the whole project.
3. **Concrete numbers, always.** "Fine-tuned a ball detector, improving precision from X% to Y% on a held-out set of Z labeled frames" is dramatically more credible than "added AI-powered ball tracking." Every evaluation you ran in §11.4 is a sentence like this waiting to be written.
4. **Model/eval artifacts, not just app code**: a Kaggle-style write-up or a Hugging Face model card for your ball detector or classifier (even a small one) puts you in front of a different audience and signals you understand the ML side specifically, not just app development.

### How to talk about it in interviews
- Lead with the **hardest real decision you made**, not the feature list — e.g., why you chose feature-based classification over an end-to-end model for serve type, or how you handled the accuracy/confidence tradeoff in the UI. Interviewers remember judgment, not feature lists.
- Be honest about limitations (monocular speed estimation, heuristic-to-classifier evolution) — this reads as engineering maturity, not weakness, especially since you documented the reasoning in this very plan.
- Have the numbers from §11.4 memorized, not just "in the repo somewhere."
- Be ready to whiteboard the architecture in §4 — a system you can explain from memory, including why each piece is where it is, is worth more than a system you can only point to code for.

### Positioning across channels
- **Resume bullet example:** "Built and shipped a native iOS app performing on-device pose estimation (Vision) and object detection (Core ML) for tennis serve analysis; fine-tuned a ball-detection model improving [metric] by [X]%, and designed a full ML pipeline from data labeling through on-device deployment."
- **LinkedIn/X:** short, regular progress posts (a clip of the app working, a chart of your model's improving accuracy) build a visible trail of real work over time — more credible to a hiring manager than a single "I built this" post at the end.
- **Open source strategically:** consider open-sourcing a self-contained, reusable piece (e.g., the phase-detection heuristic, or a tennis-ball detection model/dataset) even if the full app stays private — it's a smaller, more shareable artifact that other people can actually use and star, which compounds visibility more than a monolithic private repo ever will.
- **Community**: post technical writeups where ML/CV engineers actually look (relevant subreddits, Hacker News for a genuinely technical post, ML-focused Discord/Slack communities) rather than only general social media — the audience that recognizes the value of on-device CV work is narrower and more targeted than a general audience.

### The throughline
The project itself proves the skill; the write-ups and demos are what make that legible to someone who has 90 seconds to evaluate your portfolio before deciding whether to read further. Budget real time for §12's artifacts — a great project with no legible evidence of it is, from a hiring manager's chair, indistinguishable from no project at all.
