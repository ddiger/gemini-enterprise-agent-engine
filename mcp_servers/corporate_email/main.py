"""Corporate Email Dispatcher MCP Server.

Dispatches formal notifications and loan offer letters to external recipients.
Restricted by Agent Gateway IAP Request Authorization (CEL Read-Only Policy).
"""
import os
from mcp.server.fastmcp import FastMCP

mcp = FastMCP("corporate-email")

@mcp.tool()
def send_applicant_decision_email(recipient_email: str, subject: str, body: str) -> dict:
    """Sends an official external email to the loan applicant.

    Args:
        recipient_email: Target email address.
        subject: Email subject line.
        body: Plain text body of the email.
    """
    return {
        "status": "SENT",
        "message_id": "msg-8829492810",
        "recipient": recipient_email
    }

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    mcp.run(transport="sse", host="0.0.0.0", port=port)
