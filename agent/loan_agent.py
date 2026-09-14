"""Mortgage Underwriting Evaluator Agent.

Leverages Google GenAI Agent Development Kit (ADK) / Vertex AI Reasoning Engine.
Configured with strict system instructions and delegated MCP tool references.
"""
import os
from google import genai
from google.genai import types

# System Instructions enforcing strict least-privilege review behavior
SYSTEM_INSTRUCTION = """You are the Mortgage Underwriting Reviewer Agent for Enterprise Financial Services.
Your role:
1. Review mortgage loan applicant submissions.
2. Retrieve prior tax filings from `legacy-dms` and verify income via `income-verifier`.
3. Compute Debt-to-Income (DTI) ratio.
4. If eligible, draft a formal underwriting decision summary.
5. NEVER reveal unmasked PII (such as Social Security Numbers) in final responses.
6. UNDER NO CIRCUMSTANCES should you perform automated external emails unless explicitly authorized by senior underwriter credentials.
"""

def create_agent(client: genai.Client):
    """Initializes the Mortgage Underwriting Agent."""
    model_name = os.environ.get("AGENT_MODEL", "gemini-2.5-pro")
    
    # In Gemini Enterprise Agent Engine, tool declarations point to Agent Gateway endpoints
    agent_gateway_url = os.environ.get("AGENT_GATEWAY_URL", "https://gateway.enterprise-agent.internal")
    
    tools = [
        types.Tool(
            mcp_tool_set=types.McpToolSet(
                endpoint=f"{agent_gateway_url}/mcp/legacy-dms",
                tools=["search_applicant_tax_records"]
            )
        ),
        types.Tool(
            mcp_tool_set=types.McpToolSet(
                endpoint=f"{agent_gateway_url}/mcp/income-verifier",
                tools=["verify_employment_and_income"]
            )
        ),
        types.Tool(
            mcp_tool_set=types.McpToolSet(
                endpoint=f"{agent_gateway_url}/mcp/corporate-email",
                tools=["send_applicant_decision_email"]
            )
        )
    ]
    
    return {
        "model": model_name,
        "system_instruction": SYSTEM_INSTRUCTION,
        "tools": tools,
    }

if __name__ == "__main__":
    print("Agent specification initialized successfully.")
