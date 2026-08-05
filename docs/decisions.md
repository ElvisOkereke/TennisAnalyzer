# Phase 0 Decisions

Concrete record of the framework/tooling decisions made in §3 of [the playbook](tennis-serve-app-full-playbook.md), so they don't get re-litigated later. Each entry links back to the section with the full tradeoff analysis.

| Area | Decision | Playbook ref |
|---|---|---|
| Mobile framework | Native iOS (Swift + SwiftUI), single platform | §3.1 |
| Pose estimation | Apple Vision framework (`VNDetectHumanBodyPoseRequest`), first-party, no bundled model | §3.2 |
| Ball detection | Bootstrap with generic COCO "sports ball" detector; fine-tune on labeled data at Phase 4 | §3.3 |
| Serve-type classification | Rule-based heuristic first (Phase 3c); simple interpretable trained classifier at Phase 4 | §3.4, §11.3 |
| Backend & storage | Client-only through Phase 3; Supabase (Postgres + auth + storage) from Phase 4 | §3.5 |
| Marketing site hosting | Static hosting (Vercel/Netlify/Cloudflare Pages), decided but not needed until Phase 6 | §3.6 |
| Dev environment | Windows primary; cloud Mac (Scaleway, M2-M tier) leased in short batches for Xcode-only work | §3.7 |
| Crash reporting | Sentry — decided now, SDK wired into the app during the first Mac lease once the Xcode project exists | §9 |

## Not yet decided / deferred

- CI provider: using GitHub Actions as the default (matches free-tier-first approach elsewhere in the plan); revisit only if a specific need arises.
- Git hosting: GitHub (per §12's "public GitHub repo with a genuinely good README" portfolio goal).

## Mac lease TODOs carried from §3.7

These require an actual Apple developer account / Scaleway Mac instance and can't be done from Windows. Full step-by-step: [mac-setup.md](mac-setup.md).

- [x] Provision first Scaleway Mac mini lease using `scripts/mac-lease-setup.sh`.
- [x] Xcode project scaffolding (`ios-app/TennisAnalyzer`), camera usage description set.
- [x] Confirm the record/upload/playback screens compile — verified by CI (`ios` job in `ci.yml`), building for Simulator on every push.
- [x] Run the app in Simulator and confirm Upload Clip → Playback works end-to-end (verified 2026-08-05, via `xcrun simctl addmedia` to seed a clip since the Simulator has no camera). This satisfies Phase 0's definition of done.
- [ ] Verify live camera capture on a real device — deliberately deferred (2026-08-05): the leased Mac can't be USB-paired with a phone it never physically touches, so this needs either a $99/yr Developer Program + TestFlight enrollment (moved up from Phase 6) or one-time local Mac access. Not required for Phase 0 per the playbook (§5, allows Simulator).
- [ ] Vision framework integration test (`VNDetectHumanBodyPoseRequest`) — this is Phase 1/2 scope, not blocking Phase 0.
- [ ] Create Sentry account, add iOS SDK once the Xcode project exists.
