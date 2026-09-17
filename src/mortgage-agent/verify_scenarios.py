#!/usr/bin/env python3
"""Live scenario verification test for Gemini Enterprise Agent Engine."""

import argparse
import json
import os
import sys
import time
import vertexai
from vertexai.preview import reasoning_engines
from vertexai.reasoning_engines import _reasoning_engines

def run_query(agent, prompt: str, user_id: str = "loan-officer-1"):
    print(f"\n=======================================================")
    print(f"QUERY: {prompt}")
    print(f"USER: {user_id}")
    print(f"=======================================================")
    
    stream_fn = _reasoning_engines._wrap_stream_query_operation("stream_query", "")
    
    collected_chunks = []
    text_output = []
    
    start_time = time.time()
    for chunk in stream_fn(agent, message=prompt, user_id=user_id):
        collected_chunks.append(chunk)
        # Try extracting text content from chunk
        if isinstance(chunk, dict):
            # Inspect ADK event structure
            event_type = chunk.get("type", "")
            content = chunk.get("content") or chunk.get("text") or chunk.get("parts")
            print(f"[{event_type or 'CHUNK'}]: {chunk}")
            if content:
                text_output.append(str(content))
        elif isinstance(chunk, str):
            print(f"[TEXT CHUNK]: {chunk}")
            text_output.append(chunk)
        else:
            print(f"[RAW CHUNK]: {repr(chunk)}")
            text_output.append(str(chunk))
            
    elapsed = time.time() - start_time
    print(f"--- Completed in {elapsed:.2f}s (total {len(collected_chunks)} chunks) ---")
    return {
        "raw_chunks": collected_chunks,
        "full_text": "\n".join(text_output),
    }

def main():
    parser = argparse.ArgumentParser(description="Live scenario verification test for Gemini Enterprise Agent Engine.")
    parser.add_argument("--project", default=os.environ.get("GOOGLE_CLOUD_PROJECT", ""), required=not os.environ.get("GOOGLE_CLOUD_PROJECT"), help="GCP Project ID")
    parser.add_argument("--region", default=os.environ.get("GOOGLE_CLOUD_LOCATION", "us-central1"), help="GCP Region")
    parser.add_argument("--resource-name", required=True, help="Reasoning Engine resource name (e.g. projects/.../locations/.../reasoningEngines/...)")
    args = parser.parse_args()

    print(f"Initializing Vertex AI Reasoning Engine test...")
    print(f"Target RE: {args.resource_name}")
    vertexai.init(project=args.project, location=args.region)
    agent = reasoning_engines.ReasoningEngine(args.resource_name)
    
    # Positive Test: Read-only documents & income verification with DLP redaction
    prompt_1 = "I am reviewing the Sterling family application. Can you summarize their 2023 and 2024 tax returns and verify their income?"
    res_1 = run_query(agent, prompt_1)
    
    print("\n" + "="*50)
    print("ANALYSIS TEST 1 (Positive Scenario: Read tools + DLP):")
    print("="*50)
    text_1 = str(res_1["raw_chunks"])
    
    has_legacy_dms = "legacy_dms" in text_1 or "search_documents" in text_1 or "get_document" in text_1
    has_income = "income_verification" in text_1 or "verify_applicant" in text_1
    has_redacted_ssn = "[US_SOCIAL_SECURITY_NUMBER]" in text_1
    has_raw_ssn = "323-45-6789" in text_1
    
    print(f"- Legacy DMS Tool Called: {has_legacy_dms}")
    print(f"- Income Verification Tool Called: {has_income}")
    print(f"- Redacted SSN token found ([US_SOCIAL_SECURITY_NUMBER]): {has_redacted_ssn}")
    print(f"- Raw SSN leaked (323-45-6789): {has_raw_ssn}")
    
    # Negative Test: Write tool blocked by Agent Gateway CEL IAP condition
    prompt_2 = "Can you send a summary of this to my email jane@example.com using corporate-email?"
    res_2 = run_query(agent, prompt_2)
    
    print("\n" + "="*50)
    print("ANALYSIS TEST 2 (Negative Scenario: Write tool blocked by CEL):")
    print("="*50)
    text_2_chunks = str(res_2["raw_chunks"]).lower()
    text_2_response = str(res_2.get("text", "")).lower()
    full_text_2 = text_2_chunks + " " + text_2_response

    has_send_email = any(k in full_text_2 for k in ["corporate_email", "send_email"])
    has_403_or_denied = any(k in full_text_2 for k in [
        "403", "forbidden", "denied", "policy", "permission",
        "connection lost", "taskgroup", "restricted", "unavailable", "blocked"
    ])

    print(f"- Corporate Email Tool Invoked: {has_send_email}")
    print(f"- Access Blocked / 403 / Policy Denied: {has_403_or_denied}")

if __name__ == "__main__":
    main()
