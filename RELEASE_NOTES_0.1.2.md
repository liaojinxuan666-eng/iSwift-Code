# iSwift Code 0.1.2 Release Notes

0.1.2 is the project-infrastructure release.

The main achievement is not a single new syntax feature. It is the transition
from a single-source Swift runner toward a reusable mobile development platform.

## Highlights

- Multi-file project/workspace architecture
- Persistent local projects
- Project browser and templates
- Entry-file management
- Unsaved-buffer-aware project snapshots
- Provider-based compiler architecture
- AI provider contract
- Plugin manifest/permissions/registry foundation
- Permission-checked Host Services
- Built-in / Wasm / remote-service extension model
- Stock-iOS-safe architecture constraints
- Locked 0.1.3 App Preview roadmap

## Compatibility baseline

- iOS deployment target: 17.0
- stock/non-jailbroken device remains the primary target
- XcodeGen project generation
- GitHub Actions build/test gate

## Next

0.1.3 begins App Preview Foundation:

`ProjectWorkspace -> PreviewProvider -> Preview IR -> Signed Preview Runtime`
