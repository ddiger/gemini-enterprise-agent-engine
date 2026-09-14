"""Legacy Document Management System (DMS) MCP Server.

Provides read-only access to applicant tax records and historic filings.
"""
import os
from mcp.server.fastmcp import FastMCP

mcp = FastMCP("legacy-dms")

MOCK_DATABASE = {
    "Sterling": {
        "applicant_name": "Eleanor Sterling",
        "tax_year": 2025,
        "reported_agi": 185000.00,
        "filing_status": "Married Filing Jointly",
        "ssn": "987-65-4321",
        "documents": ["W2-2025.pdf", "1040-Schedule-C.pdf"]
    }
}

@mcp.tool()
def search_applicant_tax_records(family_name: str) -> dict:
    """Searches legacy archive for filed tax documents and reported AGI.

    Args:
        family_name: Last name of the applicant family.
    """
    record = MOCK_DATABASE.get(family_name)
    if not record:
        return {"status": "NOT_FOUND", "message": f"No tax records found for family: {family_name}"}
    return {
        "status": "SUCCESS",
        "records": record
    }

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    mcp.run(transport="sse", host="0.0.0.0", port=port)
