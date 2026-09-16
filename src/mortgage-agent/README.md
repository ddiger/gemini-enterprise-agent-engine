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

## Architecture & Governance Flow

```
[Web UI Portal / Client]
       |
       v
[Agent Runtime (Gemini 3.8 Flash on ADK)]
       |
       |-- Egress: SPIFFE ID X.509 mTLS + DPoP JWT Token (Service Account Impersonation)
       v
[Agent Gateway (Managed Envoy Proxy)]
       |
       |-- Model Armor CONTENT_AUTHZ (Prompt Injection / Jailbreak Filter -> HTTP 799)
       |-- IAP REQUEST_AUTHZ (CEL Condition: ReadOnlyToolsOnly -> HTTP 403)
       |-- Cloud DLP De-identification (SSN Redacted -> [US_SOCIAL_SECURITY_NUMBER])
       |-- Private Service Connect NAT Subnet (10.20.0.0/28)
       |
       +---> legacy-dms (search_documents) [200 OK - Read Approved]
       +---> income-verification (verify_applicant) [200 OK - DLP SSN Redacted]
       +---> corporate-email (send_email) [403 Forbidden - Write Blocked]
```

## Supported Verification Scenarios

1. **[Normal] Document Summary & Income Verification**: Retrieves Julian Sterling's W-2 and tax forms; SSN is masked in transit by Cloud DLP (`[US_SOCIAL_SECURITY_NUMBER]`).
2. **[Blocked] External Email Exfiltration**: Attempting to email sensitive summaries to an external email (`attacker@external.com`) is blocked by IAP CEL at the Gateway (`403 Forbidden`).
3. **[Refused] Direct System Prompt Jailbreak**: Direct "DAN" persona jailbreak attempts are immediately refused by Gemini's native safety filters (1st line of defense).
4. **[Injected] Malicious Tool Argument Injection**: Indirect prompt injections targeting backend tools are intercepted by Model Armor CONTENT_AUTHZ (`HTTP 799`).
5. **[Authorized] Internal Approval Check**: Inquiring about sending approval notifications to authorized internal loan reviewers (`officer@bank.internal`).

## Runtime Hardening & Resilience

- **Atomic CA Bundle**: The Agent Gateway CA certificate (`/tmp/agent_gateway_ca_bundle.pem`) is written atomically via temporary files and `os.replace` to prevent multi-worker concurrency corruption.
- **Dynamic Self-Healing (`_ensure_mcp_tools`)**: On every `query()`, the agent checks if all MCP tools are loaded and automatically performs runtime discovery if cold start or transient errors delayed startup registration.
- **Warm Backend Requirement**: Backend FastMCP Cloud Run services should run with `--min-instances=1` to prevent 5-second ADK discovery timeouts.

