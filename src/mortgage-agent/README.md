# Mortgage Assistant Agent

ADK mortgage assistant agent deployed to **Vertex AI Agent Runtime (Reasoning Engine)** powered by **Gemini 3.8 Flash**. Connects to legacy DMS, income verification, and corporate email FastMCP servers via **Agent Gateway** with **Agent Identity (SPIFFE mTLS + DPoP)**.

## Prerequisites

- Terraform infrastructure deployed (VPC, Agent Gateway, Model Armor, Agent Registry)
- FastMCP servers deployed to Cloud Run
- `uv` installed for Python dependency management (Python >= 3.12)

## Deploy

```bash
cd src/mortgage-agent
uv sync

uv run python deploy_agent.py \
  --project=${PROJECT_ID} \
  --region=${REGION} \
  --model=gemini-3.8-flash \
  --enable-agent-identity \
  --agent-name=mortgage-agent \
  --agent-gateway=projects/${PROJECT_ID}/locations/${REGION}/agentGateways/agent-gateway \
  --mcp-invoker-sa=$(terraform -chdir=../../terraform output -raw agent_mcp_invoker_email) \
  --staging-bucket=gs://${PROJECT_ID}-staging \
  --model-endpoint-location=global
```

## Architecture

```
[Agent Runtime (Gemini 3.8 Flash on ADK)]
       |
       |-- Egress: SPIFFE ID X.509 mTLS + DPoP JWT Token
       v
[Agent Gateway (Managed Envoy Proxy)]
       |
       |-- Model Armor CONTENT_AUTHZ (Prompt Injection Filter)
       |-- IAP REQUEST_AUTHZ (CEL Condition: ReadOnlyToolsOnly)
       |-- Private Service Connect NAT Subnet (10.20.0.0/28)
       |
       +---> legacy-dms (search_documents) [200 OK]
       +---> income-verification (verify_applicant) [DLP SSN Redacted]
       +---> corporate-email (send_email) [403 Forbidden Blocked]
```
