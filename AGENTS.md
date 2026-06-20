# Repository Guidelines

## Project Structure & Module Organization

This repository contains a Helm 3 application chart for a Redis cluster. Chart metadata lives in `Chart.yaml`, while user-facing defaults are defined in `values.yaml`. Kubernetes resources are under `templates/`: `_helpers.tpl` contains reusable named templates, `statefulset.yaml` defines Redis and exporter containers, and the remaining files define services, ConfigMaps, initialization scripts, and monitoring resources. CI and release workflows live in `.github/workflows/`. Keep parameter documentation in `README.md` synchronized with changes to `values.yaml`.

## Build, Test, and Development Commands

- `helm lint .` performs basic chart and template validation.
- `helm template redis-cluster .` renders all manifests locally for inspection.
- `helm template redis-cluster . -f custom-values.yaml` tests a specific configuration.
- `helm kubeconform .` runs the same Kubernetes schema validation used by CI; install the `jtyr/kubeconform-helm` plugin first.
- `helm package . --dependency-update` creates a distributable chart archive.

Before submitting changes, run both `helm lint .` and `helm kubeconform .`. Render targeted values whenever a feature adds conditional YAML.

## Coding Style & Naming Conventions

Use two-space indentation in YAML and preserve correct nesting after Helm directives. Name values in lower camel case (`minReadySeconds`, `extraEnvs`) and Kubernetes resources in kebab case. Prefix named helpers with `redis-cluster.`, for example `redis-cluster.extraEnvs`. Use whitespace-trimming operators (`{{-` and `-}}`) carefully; always inspect rendered output when changing loops or includes. Quote string values where Kubernetes may otherwise infer booleans or numbers.

## Testing Guidelines

There is no standalone unit-test suite. Tests are rendered-manifest and schema checks. Cover both enabled and disabled branches, empty lists, multiple list entries, and nested objects such as `valueFrom`. Never commit credentials in test values; use placeholders.

## Commit & Pull Request Guidelines

Recent history follows Conventional Commit-style subjects: `feat:`, `chore:`, `ci:`, and `style:`. Use an imperative, concise subject, such as `feat: add Redis environment variables`. Pull requests should explain behavior changes, list validation commands run, link relevant issues, and include a focused rendered YAML excerpt when template output changes. Update `README.md`, `values.yaml`, and the chart version when required for a release.

## Security & Configuration Tips

Do not place real Redis passwords or registry tokens in committed values or rendered manifests. Prefer Kubernetes Secrets via `valueFrom.secretKeyRef` for sensitive environment variables.
