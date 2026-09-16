# Mortgage Underwriting Loan Officer Interactive Web UI

Interactive demo Web UI portal for the **Gemini Enterprise Agent Platform** mortgage underwriting loan officer agent, deployed on **Cloud Run** with FastAPI and Server-Sent Events (SSE).

## Features

- **Modern Enterprise Styling**: Clean Plus Jakarta Sans typography, subtle glassmorphism navigation, responsive 3-column desktop layout.
- **5 One-Click Live Verification Scenarios**:
  1. `[Normal] Summary & Verification (Cloud DLP SSN Redaction)`
  2. `[Block] External Email Exfiltration (IAP CEL 403 Forbidden)`
  3. `[Refusal] Direct System Prompt Jailbreak (LLM Self-Defense Guard)`
  4. `[Injection] Malicious Tool Argument Injection (Model Armor HTTP 799)`
  5. `[Authorized] Internal Approval Notification (Governance Policy Check)`
- **Architecture: Before vs After Modal**: Compares direct Cloud Run connections (4 major security risks) against centralized Agent Gateway governance.
- **Under-the-Hood Inspector Panel**:
  - **Live L7 Trace Stream**: Visual timeline of agent reasoning, tool invocations, and policy evaluation.
  - **Policy Rulebook**: Exact IAP CEL expressions, Model Armor configurations, and Cloud DLP infoTypes.
  - **Cloud Console Deep Links**: Direct one-click access to `sanitize_operations`, `gateway_requests`, and `Cloud Trace Explorer`.

## Environment Variables

| Variable | Description | Example |
| :--- | :--- | :--- |
| `GOOGLE_CLOUD_PROJECT` | GCP project ID where the Reasoning Engine is deployed | `jhlee1` |
| `GOOGLE_CLOUD_LOCATION` | GCP region for the Reasoning Engine and Vertex AI | `us-central1` |
| `REASONING_ENGINE_RESOURCE` | Full resource path of the deployed Vertex AI Reasoning Engine | `projects/49152802892/locations/us-central1/reasoningEngines/3827001403323187200` |
| `PORT` | Web server listening port (default: `8080`) | `8080` |

## Local Development

```bash
cd src/web-ui
pip install -r requirements.txt

export GOOGLE_CLOUD_PROJECT="<your-project-id>"
export GOOGLE_CLOUD_LOCATION="us-central1"
export REASONING_ENGINE_RESOURCE="projects/<project-number>/locations/us-central1/reasoningEngines/<agent-id>"

uvicorn app:app --host 0.0.0.0 --port 8080 --reload
```

Open `http://localhost:8080` in your browser.

## Cloud Run Deployment

Deploy directly from source using Google Cloud Build and Cloud Run:

```bash
gcloud run deploy mortgage-agent-ui \
  --source src/web-ui \
  --region=${REGION} \
  --project=${PROJECT_ID} \
  --service-account=${PROJECT_NUMBER}-compute@developer.gserviceaccount.com \
  --set-env-vars GOOGLE_CLOUD_PROJECT=${PROJECT_ID},GOOGLE_CLOUD_LOCATION=${REGION},REASONING_ENGINE_RESOURCE=projects/${PROJECT_NUMBER}/locations/${REGION}/reasoningEngines/${AGENT_ID} \
  --allow-unauthenticated \
  --port 8080 \
  --memory 1Gi \
  --cpu 1
```
