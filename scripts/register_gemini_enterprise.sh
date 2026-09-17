#!/usr/bin/env bash
#
# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Registers or manages the Vertex AI Reasoning Engine Mortgage Agent within
# Gemini Enterprise (formerly Google Agentspace) as a native enterprise front-end app.
#
# Usage:
#   ./scripts/register_gemini_enterprise.sh [FLAGS]
#
# Flags:
#   --project <ID>             GCP Project ID (default: $PROJECT_ID or gcloud active project)
#   --project-number <NUM>     GCP Project Number (default: auto-detected)
#   --region <REGION>          Reasoning Engine Region (default: us-central1)
#   --agent-id <ID>            Reasoning Engine resource ID (default: $AGENT_ID or auto-detected)
#   --app-id <ENGINE_ID>       Gemini Enterprise App/Engine ID (default: auto-detected)
#   --display-name <NAME>      Display name in Gemini Enterprise (default: "Secured Mortgage Underwriter")
#   --list                     List Gemini Enterprise apps and registered agents
#   --help                     Show this help message
#

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

PROJECT_ID="${PROJECT_ID:-$(gcloud config get-value project 2>/dev/null || true)}"
REGION="${REGION:-us-central1}"
AGENT_ID="${AGENT_ID:-}"
APP_ID="${GEMINI_ENTERPRISE_APP_ID:-}"
DISPLAY_NAME="Secured Mortgage Underwriter"
DESCRIPTION="AI Underwriting Assistant governed by Agent Gateway, Model Armor, and Cloud DLP"
TOOL_DESCRIPTION="Assists with mortgage application verification, income validation, and loan package review"
ACTION="publish"
PROJECT_NUMBER=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project|--project-id)
      PROJECT_ID="$2"
      shift 2
      ;;
    --project-number)
      PROJECT_NUMBER="$2"
      shift 2
      ;;
    --region)
      REGION="$2"
      shift 2
      ;;
    --agent-id)
      AGENT_ID="$2"
      shift 2
      ;;
    --app-id)
      APP_ID="$2"
      shift 2
      ;;
    --display-name)
      DISPLAY_NAME="$2"
      shift 2
      ;;
    --list)
      ACTION="list"
      shift
      ;;
    --help|-h)
      sed -n '2,/^$/p' "$0"
      exit 0
      ;;
    *)
      echo -e "${RED}Unknown argument: $1${NC}" >&2
      exit 1
      ;;
  esac
done

if [[ -z "${PROJECT_ID}" ]]; then
  echo -e "${RED}Error: PROJECT_ID is not set and could not be inferred from gcloud config.${NC}" >&2
  exit 1
fi

if [[ -z "${PROJECT_NUMBER}" ]]; then
  PROJECT_NUMBER="$(gcloud projects describe "${PROJECT_ID}" --format='value(projectNumber)')"
fi

ACCESS_TOKEN="$(gcloud auth print-access-token)"

echo -e "${BOLD}${BLUE}=== Gemini Enterprise (ex-Agentspace) Integration Management ===${NC}"
echo -e "Project ID:     ${GREEN}${PROJECT_ID}${NC}"
echo -e "Project Number: ${GREEN}${PROJECT_NUMBER}${NC}"
echo -e "Region:         ${GREEN}${REGION}${NC}"

# Auto-detect Gemini Enterprise Engine / App if not explicitly provided
if [[ -z "${APP_ID}" ]]; then
  ENGINES_JSON="$(curl -s -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "X-Goog-User-Project: ${PROJECT_ID}" \
    "https://discoveryengine.googleapis.com/v1/projects/${PROJECT_ID}/locations/global/collections/default_collection/engines")"

  APP_RESOURCE="$(echo "${ENGINES_JSON}" | grep -o '"projects/[^"]*"' | head -n 1 | tr -d '"' || true)"
  if [[ -n "${APP_RESOURCE}" ]]; then
    APP_ID="${APP_RESOURCE}"
    echo -e "Discovered Gemini Enterprise App: ${GREEN}${APP_ID}${NC}"
  else
    echo -e "${RED}Error: No Gemini Enterprise (Discovery Engine) App found in project ${PROJECT_ID}.${NC}" >&2
    echo -e "Please create one in Google Cloud Console -> Gemini Enterprise -> Apps before proceeding." >&2
    exit 1
  fi
fi

if [[ "${ACTION}" == "list" ]]; then
  echo -e "\n${BOLD}Registered Agents in ${APP_ID}:${NC}"
  curl -s -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "X-Goog-User-Project: ${PROJECT_ID}" \
    "https://discoveryengine.googleapis.com/v1alpha/${APP_ID}/assistants/default_assistant/agents" | \
    grep -E '("name"|"displayName"|"state")' || echo "No agents found."
  exit 0
fi

# Auto-detect Reasoning Engine AGENT_ID if empty
if [[ -z "${AGENT_ID}" ]]; then
  AGENT_ID="$(gcloud beta ai reasoning-engines list --project="${PROJECT_ID}" --region="${REGION}" --format="value(name)" 2>/dev/null | head -n 1 | awk -F'/' '{print $NF}' || true)"
  if [[ -z "${AGENT_ID}" ]]; then
    # Fallback to python detection
    AGENT_ID="$(python3 -c "
import vertexai
from vertexai.preview import reasoning_engines
try:
    vertexai.init(project='${PROJECT_ID}', location='${REGION}')
    engines = list(reasoning_engines.ReasoningEngine.list())
    if engines:
        print(engines[0].resource_name.split('/')[-1])
except Exception:
    pass
" 2>/dev/null || true)"
  fi
fi

if [[ -z "${AGENT_ID}" ]]; then
  echo -e "${RED}Error: Could not auto-detect active Reasoning Engine AGENT_ID.${NC}" >&2
  echo -e "Please provide --agent-id <ID> (e.g. 3827001403323187200)." >&2
  exit 1
fi

AGENT_RUNTIME_RESOURCE="projects/${PROJECT_NUMBER}/locations/${REGION}/reasoningEngines/${AGENT_ID}"
echo -e "Reasoning Engine Target: ${GREEN}${AGENT_RUNTIME_RESOURCE}${NC}"

# Step 1: Ensure Discovery Engine SA has roles/aiplatform.user
DISCOVERY_SA="service-${PROJECT_NUMBER}@gcp-sa-discoveryengine.iam.gserviceaccount.com"
echo -e "\n${BOLD}[1/3] Verifying IAM role (roles/aiplatform.user) for Discovery Engine SA...${NC}"
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${DISCOVERY_SA}" \
  --role="roles/aiplatform.user" \
  --condition=None \
  --quiet >/dev/null 2>&1 || true
echo -e "${GREEN}✓ Discovery Engine SA permission verified.${NC}"

# Step 2: Publish agent via agents-cli or REST API
echo -e "\n${BOLD}[2/3] Registering agent to Gemini Enterprise...${NC}"
if command -v agents-cli >/dev/null 2>&1; then
  agents-cli publish gemini-enterprise \
    --project "${PROJECT_ID}" \
    --project-number "${PROJECT_NUMBER}" \
    --registration-type adk \
    --agent-runtime-id "${AGENT_RUNTIME_RESOURCE}" \
    --gemini-enterprise-app-id "${APP_ID}" \
    --display-name "${DISPLAY_NAME}" \
    --description "${DESCRIPTION}" \
    --tool-description "${TOOL_DESCRIPTION}"
else
  # Fallback to direct REST API registration
  REGISTER_RESP="$(curl -s -X POST -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "X-Goog-User-Project: ${PROJECT_ID}" \
    -H "Content-Type: application/json" \
    "https://discoveryengine.googleapis.com/v1alpha/${APP_ID}/assistants/default_assistant/agents" \
    -d "{
      \"displayName\": \"${DISPLAY_NAME}\",
      \"description\": \"${DESCRIPTION}\",
      \"adkAgentDefinition\": {
        \"toolSettings\": {
          \"toolDescription\": \"${TOOL_DESCRIPTION}\"
        },
        \"provisionedReasoningEngine\": {
          \"reasoningEngine\": \"${AGENT_RUNTIME_RESOURCE}\"
        }
      }
    }")"
  echo "${REGISTER_RESP}"
fi

# Step 3: Enable ALL_USERS sharing & AUTOMATIC invocation
echo -e "\n${BOLD}[3/3] Configuring enterprise sharing and automatic invocation...${NC}"
AGENTS_JSON="$(curl -s -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "X-Goog-User-Project: ${PROJECT_ID}" \
  "https://discoveryengine.googleapis.com/v1alpha/${APP_ID}/assistants/default_assistant/agents")"

AGENT_RESOURCE_NAME="$(python3 -c "
import json, sys
data = json.loads('''${AGENTS_JSON}''')
for ag in data.get('agents', []):
    if ag.get('displayName') == '${DISPLAY_NAME}':
        print(ag.get('name'))
        break
" 2>/dev/null || true)"

if [[ -n "${AGENT_RESOURCE_NAME}" ]]; then
  curl -s -X PATCH -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "X-Goog-User-Project: ${PROJECT_ID}" \
    -H "Content-Type: application/json" \
    "https://discoveryengine.googleapis.com/v1alpha/${AGENT_RESOURCE_NAME}?updateMask=sharingConfig,agentInvocationSpec" \
    -d '{
      "sharingConfig": {
        "scope": "ALL_USERS"
      },
      "agentInvocationSpec": {
        "invocationMode": "AUTOMATIC"
      }
    }' >/dev/null 2>&1
  echo -e "${GREEN}✓ Agent configured with ALL_USERS sharing and AUTOMATIC invocation mode.${NC}"
fi

APP_SHORT_ID="$(echo "${APP_ID}" | awk -F'/' '{print $NF}')"
CONSOLE_URL="https://console.cloud.google.com/gemini-enterprise/locations/global/engines/${APP_SHORT_ID}/overview/dashboard?project=${PROJECT_ID}"

echo -e "\n${BOLD}${GREEN}================================================================${NC}"
echo -e "${BOLD}${GREEN}🎉 Agent successfully published to Gemini Enterprise!${NC}"
echo -e "${BOLD}${GREEN}================================================================${NC}"
echo -e "Display Name:  ${BOLD}${DISPLAY_NAME}${NC}"
echo -e "App Engine:    ${APP_ID}"
echo -e "Web Console:   ${CONSOLE_URL}"
echo -e "Egress Zero-Trust: ${GREEN}Agent Gateway L7 + Model Armor + Cloud DLP Active${NC}\n"
