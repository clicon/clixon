# Clixon coverage container

Builds and runs a Docker container that compiles Clixon and CLIgen with
`--coverage`, runs the full test suite, and generates lcov coverage reports
for both projects.

## Usage

```bash
cd docker/coverage

# Build image and run container, extract reports, print summary
make coverage
```

This produces:
- `coverage-clixon.info` — lcov report for Clixon
- `coverage-cligen.info` — lcov report for CLIgen
- `cligen-sha.txt` — the exact CLIgen commit SHA compiled into the image

## Output

After `make coverage` completes, lcov summaries are printed for both projects.
The `.info` files can be uploaded to Codecov or viewed locally:

```bash
genhtml coverage-clixon.info --output-directory out-clixon
genhtml coverage-cligen.info --output-directory out-cligen
```

## CI

The coverage reports are uploaded automatically to
[Codecov](https://codecov.io) by the GitHub Actions workflow
`.github/workflows/coverage.yml`, which runs weekly (Monday 02:00 UTC)
and can also be triggered manually via `workflow_dispatch`.

