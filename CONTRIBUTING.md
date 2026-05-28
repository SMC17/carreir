# Contributing

This is an operator-maintained project. Pull requests welcome with the following discipline:

- One change per PR. Small, reviewable, with a clear motivation.
- Tests / lint must pass. CI is the floor — every push runs `zig build test --summary all` plus the test-count-drift check.
- Match the existing style.
- Justify new dependencies — smaller is better. The repo currently has zero runtime dependencies.
- Documentation changes welcome at any time.

## No AI-authored code from external contributors

External pull requests must not be authored by AI / LLM code generators.
This is a trust constraint specific to this project: we do not accept
opaque AI-authored contributions from outside the maintainer team. If
you wrote the code yourself, you are welcome. If you used AI assistance,
please disclose it in the PR description and expect a slower review or
a request for a manual rewrite.

## Security

See [SECURITY.md](SECURITY.md) for vulnerability disclosure.
