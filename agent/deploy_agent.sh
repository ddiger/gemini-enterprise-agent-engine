#!/usr/bin/env bash
# ==============================================================================
# Deploy Agent to Vertex AI Reasoning Engine via agents-cli
# Binds Agent Identity and Agent Gateway Egress
# ==============================================================================
set -euo pipefail

PROJECT_ID="${PROJECT_ID:-$(gcloud config get-value project)}"
REGION="${REGION:-us-central1}"
SA_EMAIL="mortgage-evaluator-sa@${PROJECT_ID}.iam.gserviceaccount.com"
NETWORK_ATTACHMENT="projects/${PROJECT_ID}/regions/${REGION}/networkAttachments/agent-gateway-attachment"

echo "Deploying Mortgage Underwriting Agent..."
echo "Project:            ${PROJECT_ID}"
echo "Region:             ${REGION}"
echo "Service Account:    ${SA_EMAIL}"
echo "Network Attachment: ${NETWORK_ATTACHMENT}"

agents-cli deploy agent-runtime \
  --project="${PROJECT_ID}" \
  --region="${REGION}" \
  --display-name="mortgage-agent" \
  --service-account="${SA_EMAIL}" \
  --network-attachment="${NETWORK_ATTACHMENT}" \
  --env-vars="AGENT_MODEL=gemini-2.5-pro,AGENT_GATEWAY_URL=https://gateway.enterprise-agent.internal" \
  --source=agent/

echo "Agent deployed successfully!"
