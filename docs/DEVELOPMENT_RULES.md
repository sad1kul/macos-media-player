# Development Rules

## Core principle

Prefer the smallest clear change that solves the current problem and remains easy to merge with upstream VLC.

## Keep upstream changes narrow

Do not reformat, rename, relocate or refactor unrelated VLC code.

Before editing existing upstream code, ask:

1. Is the change required for the feature?
2. Can the feature be implemented with a smaller patch?
3. Will this make future upstream merges harder?

## Avoid artificial coding patterns

Do not introduce abstractions only because they look architectural.

Avoid:

- generic managers, providers, factories or helpers without a real need;
- wrapper classes that add no behaviour;
- one-implementation interfaces created speculatively;
- broad "clean architecture" layers around existing VLC APIs;
- catch-all utility files;
- comments that only restate the code;
- oversized generated documentation inside source files;
- fallback paths that cannot actually occur;
- swallowed errors;
- speculative plugin systems;
- mass refactors bundled with feature work.

Prefer:

- direct code;
- existing VLC conventions;
- descriptive names;
- explicit error handling;
- small, reviewable patches;
- platform-native APIs where appropriate;
- comments that explain why a non-obvious decision exists.

## Platform scope

Initial development targets Apple Silicon macOS.

Do not add Intel, Windows or Linux-specific abstractions until there is an actual requirement.

## Performance

Media frames must remain in the native playback/rendering path.

Do not move decoded video frames through JavaScript, web canvases, unnecessary CPU buffers, or redundant copies.

## Native code

Unsafe or low-level native operations must remain localized and documented where necessary.

## Testing

Every feature should identify:

- the behaviour being changed;
- the manual macOS test required;
- any automated test that is practical;
- known limitations.

Do not claim a hardware or visual behaviour is validated solely because CI passes.

## Branch, PR and validation workflow

All project changes follow this sequence:

1. Create a separate working branch from the correct baseline.
2. Implement the change on that branch.
3. Run the first build and test pass locally before opening a pull request.
4. Open a pull request only after the first test pass succeeds.
5. Run a second validation pass against the pull-request state. This should include CI where available and a fresh manual macOS build/test for native playback, windowing, hardware acceleration, or other behaviour that CI cannot prove.
6. Fix any issue on the same branch and repeat the relevant tests.
7. Merge only after both the pre-PR test and the PR validation pass succeed.

Do not merge code merely because it compiles or because CI is green when the feature depends on real macOS playback or UI behaviour.

## Commits

Use small, descriptive commits. Examples:

- `feat: add floating player window`
- `fix: preserve playback when leaving floating mode`
- `perf: avoid redundant video surface updates`
- `docs: document macOS window behaviour`

Avoid combining unrelated cleanup with feature work.
