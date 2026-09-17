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
# scripts/preflight_check.sh: Validates environment prerequisites before deployment.

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}================================================================${NC}"
echo -e "${BLUE}  Gemini Enterprise Agent Engine - Preflight Environment Check   ${NC}"
echo -e "${BLUE}================================================================${NC}"

HAS_ERROR=0

check_cmd() {
    local cmd="$1"
    local desc="$2"
    if command -v "$cmd" >/dev/null 2>&1; then
        echo -e "  [${GREEN}PASS${NC}] ${cmd} is installed (${desc})"
    else
        echo -e "  [${RED}FAIL${NC}] ${cmd} is NOT installed! (${desc})"
        HAS_ERROR=1
    fi
}

echo -e "\n${YELLOW}1. Checking Required CLI Tools:${NC}"
check_cmd "gcloud" "Google Cloud SDK CLI"
check_cmd "terraform" "Infrastructure as Code CLI"
check_cmd "skaffold" "Container build & deploy pipeline"
check_cmd "uv" "Fast Python package installer"
check_cmd "python3" "Python 3 runtime"
check_cmd "envsubst" "Environment variable substitution"
check_cmd "git" "Version control"

echo -e "\n${YELLOW}2. Checking Google Cloud Authentication & Configuration:${NC}"
ACTIVE_ACCOUNT=$(gcloud config get-value account 2>/dev/null || true)
if [ -n "$ACTIVE_ACCOUNT" ]; then
    echo -e "  [${GREEN}PASS${NC}] Active gcloud account: ${GREEN}${ACTIVE_ACCOUNT}${NC}"
else
    echo -e "  [${RED}FAIL${NC}] No active gcloud account found. Run 'gcloud auth login' first."
    HAS_ERROR=1
fi

PROJECT_ID=${PROJECT_ID:-$(gcloud config get-value project 2>/dev/null || true)}
if [ -n "$PROJECT_ID" ]; then
    echo -e "  [${GREEN}PASS${NC}] Target GCP Project: ${GREEN}${PROJECT_ID}${NC}"
else
    echo -e "  [${RED}FAIL${NC}] No GCP Project configured. Set export PROJECT_ID=... or run 'gcloud config set project <ID>'."
    HAS_ERROR=1
fi

echo -e "\n${YELLOW}3. Checking Organization ID (Required for Agent Identity / SPIFFE):${NC}"
ORG_ID=${ORG_ID:-}
if [ -z "$ORG_ID" ] && [ -n "$PROJECT_ID" ]; then
    ORG_ID=$(gcloud projects get-ancestors "$PROJECT_ID" --format="value(id)" --filter="type:organization" 2>/dev/null | head -n 1 || true)
fi

if [ -n "$ORG_ID" ]; then
    echo -e "  [${GREEN}PASS${NC}] Organization ID detected: ${GREEN}${ORG_ID}${NC}"
else
    echo -e "  [${YELLOW}WARN${NC}] Organization ID could not be auto-detected."
    echo -e "         Agent Identity (SPIFFE) requires an Org ID for federated principal bindings."
    echo -e "         If using an organization, export ORG_ID=<numeric-id>."
fi

echo -e "\n${YELLOW}4. Checking Application Default Credentials (ADC):${NC}"
if gcloud auth application-default print-access-token >/dev/null 2>&1; then
    echo -e "  [${GREEN}PASS${NC}] Application Default Credentials (ADC) active."
else
    echo -e "  [${YELLOW}WARN${NC}] ADC not configured. For Python SDK / Terraform, run:"
    echo -e "         gcloud auth application-default login"
fi

echo -e "\n${YELLOW}5. Checking Core Google Cloud APIs:${NC}"
if [ -n "$PROJECT_ID" ]; then
    REQUIRED_APIS=(
        "compute.googleapis.com"
        "run.googleapis.com"
        "aiplatform.googleapis.com"
        "agentregistry.googleapis.com"
        "iap.googleapis.com"
        "dlp.googleapis.com"
        "modelarmor.googleapis.com"
        "cloudbuild.googleapis.com"
        "artifactregistry.googleapis.com"
    )
    
    ENABLED_APIS=$(gcloud services list --project="$PROJECT_ID" --format="value(config.name)" 2>/dev/null || true)
    
    MISSING_APIS=()
    for api in "${REQUIRED_APIS[@]}"; do
        if echo "$ENABLED_APIS" | grep -q "^${api}$"; then
            echo -e "  [${GREEN}PASS${NC}] API enabled: ${api}"
        else
            echo -e "  [${YELLOW}MISS${NC}] API not enabled: ${api}"
            MISSING_APIS+=("$api")
        fi
    done
    
    if [ ${#MISSING_APIS[@]} -gt 0 ]; then
        echo -e "\n  To enable missing APIs in one command, run:"
        echo -e "  ${BLUE}gcloud services enable ${MISSING_APIS[*]} --project=${PROJECT_ID}${NC}"
    fi
fi

echo -e "\n${BLUE}================================================================${NC}"
if [ $HAS_ERROR -eq 0 ]; then
    echo -e "${GREEN}  Preflight Check Completed Successfully! Ready to deploy.     ${NC}"
else
    echo -e "${RED}  Preflight Check Failed! Please resolve the [FAIL] items above.${NC}"
    exit 1
fi
echo -e "${BLUE}================================================================${NC}"
