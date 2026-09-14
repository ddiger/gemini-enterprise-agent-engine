"""Income Verification MCP Server.

Interacts with payroll integrations to verify real-time employment and income.
Contains sensitive PII (SSN, wage slips) protected by Model Armor DLP.
"""
import os
from mcp.server.fastmcp import FastMCP

mcp = FastMCP("income-verifier")

PAYROLL_DATABASE = {
    "Eleanor Sterling": {
        "employer": "Acme Technologies Corp",
        "title": "Principal Architect",
        "base_salary": 175000.00,
        "bonus": 10000.00,
        "ssn": "987-65-4321",
        "employment_status": "Active Full-Time",
        "hire_date": "2021-03-15"
    }
}

@mcp.tool()
def verify_employment_and_income(full_name: str) -> dict:
    """Verifies real-time employment status, verified salary, and SSN.

    Args:
        full_name: Full legal name of the applicant.
    """
    data = PAYROLL_DATABASE.get(full_name)
    if not data:
        return {"status": "NOT_FOUND", "message": f"No active payroll records for: {full_name}"}
    return {
        "status": "VERIFIED",
        "data": data
    }

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    mcp.run(transport="sse", host="0.0.0.0", port=port)
