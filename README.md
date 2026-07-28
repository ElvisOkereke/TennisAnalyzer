# TennisAnalyzer

Native iOS app that analyzes tennis serve mechanics from video, starting with manual/rule-based feedback and progressing to on-device pose estimation and trained ball-tracking/serve-classification models.

Full roadmap, architecture, and rationale: [docs/tennis-serve-app-full-playbook.md](docs/tennis-serve-app-full-playbook.md).
Concrete Phase 0 decisions: [docs/decisions.md](docs/decisions.md).
Mac lease setup, step by step: [docs/mac-setup.md](docs/mac-setup.md).

## Status

**Phase 0 — Foundations.** No app shell yet. See the playbook's Phase 0 definition of done.

## Repo layout

```
ios-app/     Swift/SwiftUI app (created during the first Mac lease — see docs/decisions.md)
python/      Prototyping for geometry engine, phase-detection heuristics, tracker, model training
scripts/     One-off and provisioning scripts (e.g. Mac lease setup)
docs/        Planning and decision docs
```

## Development environment

Windows is the primary machine; a rented cloud Mac is used only for Xcode/Vision/Core ML work. See §3.7 of the playbook and [docs/decisions.md](docs/decisions.md) for the split and workflow.
