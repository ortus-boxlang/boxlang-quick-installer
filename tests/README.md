# BoxLang Test Suite

Run the complete test suite from the repository root. Docker is the only prerequisite.

**Windows**

```powershell
.\tests\run-all.ps1
```

This runs the complete Linux and Windows container matrices and restores Docker to its original container mode.

**macOS / Linux**

```sh
sh ./tests/run-all.sh
```

This runs the complete Linux container matrix. Windows Server Core containers require a Windows host.

The test suite discovers Unix specifications in `specs/*_test.sh` and Windows specifications in `powershell/*.Tests.ps1`.

## Test Layout

- `specs/` contains shell test suites. Files named `*_test.sh` are discovered automatically and run in alphabetical order.
- `powershell/` contains Windows PowerShell test suites. Files named `*.Tests.ps1` are discovered automatically.
- `run-all.sh` is the Unix-like host entry point.
- `run-all.ps1` is the Windows host entry point.

## Coverage

The suite covers helper output and version handling, Java detection, preflight dependencies, local JAR/ZIP/script artifacts, unprivileged installation, BVM behavior, and Windows PowerShell installers.

The Linux matrix runs Alpine, Debian, Ubuntu, Fedora, and Arch. CI runs offline suites and non-root suites as separate checks. The Windows matrix runs the PowerShell suites, a standard-user installer suite, and a separate offline PowerShell suite. GitHub Actions creates a disposable local account for the standard-user suite and uses an account-scoped outbound firewall rule for the offline suite; it does not require Windows containers.

## Requirements

- Docker must be running.
- The Windows command requires Docker Desktop and Windows containers; it switches between Linux and Windows container modes and restores the initial mode when finished.
- The Unix-like command requires Docker Linux containers.

The runners mount the repository read-only. Test fixtures and package prerequisites are created only inside disposable containers.

## Continuous Integration

Each runner exits nonzero on a failed suite and is suitable for CI. Linux coverage runs in the supported Linux containers; Windows coverage requires a Windows host or compatible Windows runner.

## Contributing

When changing behavior, add or update a focused test in the matching test directory:

1. Add shell tests under `specs/` using the `*_test.sh` naming convention, or PowerShell tests under `powershell/` using the `*.Tests.ps1` convention.
2. Keep tests self-contained: use temporary paths and mocks rather than host state.
3. Run the appropriate single host entry point before submitting changes.

## Troubleshooting

- Ensure Docker is running before starting either entry point.
- On Windows, enable Windows containers in Docker Desktop if the Windows portion cannot start.
- Review the failing suite output; the runners continue through their suites and summarize failures at the end.
