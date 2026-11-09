# legacy_dataform/

Put the old Dataform repository here, as a read-only reference while you port it.

- If it lives in GitHub: `git clone <repo-url> legacy_dataform/source` (or "Download ZIP" and unzip into `source/`).
- If it lives only in the Google Cloud Dataform UI: open the repository, then the development workspace,
  and download the files (or connect the repository to a Git remote first).

What you need from it: `workflow_settings.yaml` (or `dataform.json` on older versions), `definitions/`, `includes/`.
Nothing in here is run. The port goes into `dbt/models/legacy/` (see docs/DATAFORM_TO_DBT.md).

Client code: this folder is git-ignored, so it never leaves your laptop by accident.
