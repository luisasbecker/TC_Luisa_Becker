#!/usr/bin/env bash
# Run in an authenticated Google Cloud Shell. Does not upgrade the billing plan.
set -euo pipefail
project_id="${1:?Informe o ID do projeto Google Cloud}"
region="${2:-us-central1}"
service_name="pipeline-bucal"
build_account="pipeline-bucal-build@${project_id}.iam.gserviceaccount.com"
runtime_account="pipeline-bucal-runtime@${project_id}.iam.gserviceaccount.com"
source_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

gcloud services enable run.googleapis.com cloudbuild.googleapis.com artifactregistry.googleapis.com iam.googleapis.com --project="$project_id"
for account_name in pipeline-bucal-build pipeline-bucal-runtime; do
  if ! gcloud iam service-accounts describe "${account_name}@${project_id}.iam.gserviceaccount.com" --project="$project_id" >/dev/null 2>&1; then
    gcloud iam service-accounts create "$account_name" --project="$project_id" --display-name="$account_name"
  fi
done
# Only the build identity receives build permissions; runtime needs no GCP roles.
gcloud projects add-iam-policy-binding "$project_id" --member="serviceAccount:${build_account}" --role=roles/run.builder --condition=None >/dev/null

gcloud run deploy "$service_name" --project="$project_id" --region="$region" \
  --source="$source_dir" \
  --build-service-account="projects/${project_id}/serviceAccounts/${build_account}" \
  --service-account="$runtime_account" \
  --allow-unauthenticated --cpu=1 --memory=512Mi --concurrency=2 \
  --min=0 --max=1 --min-instances=0 --max-instances=1 \
  --timeout=60 --cpu-throttling --no-cpu-boost

gcloud run services describe "$service_name" --project="$project_id" --region="$region" --format='value(status.url)'
