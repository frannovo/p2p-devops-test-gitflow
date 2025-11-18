## TODO Improvements

- Add pre-commit hooks to ensure linter rules are meet before push
- Add paths-ignore on github actions to prevent trigger pipelines when it is not needed
- Add semver tagging and release workflow
- Improve workflow organization for reusability
- Use trivy for dependency vulnerability scanning and secrets scanning
- Add SAST for the goapp helm chart using trivy
- Add ServiceMonitor for goapp application monitoring
- Add attestation to sign build provenance (https://github.com/actions/attest-build-provenance)
- Configure repository level security settings
