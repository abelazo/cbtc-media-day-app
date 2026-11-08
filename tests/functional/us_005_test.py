"""
Functional test for US-005: Personal data never reaches the logs.

Makes a real request to the deployed API Gateway and inspects the CloudWatch log groups of the
authorizer and content lambdas, asserting the DNI, name and raw credential are never written.
"""

import base64
import os
import random
import time
import uuid

import boto3
import pytest
import requests

ENVIRONMENT = os.getenv("ENVIRONMENT", "dev")
PROJECT_NAME = "cbtc-media-day"
LOG_GROUPS = [
    f"/aws/lambda/{PROJECT_NAME}-{ENVIRONMENT}-authorizer",
    f"/aws/lambda/{PROJECT_NAME}-{ENVIRONMENT}-content",
]
CONTENT_LOG_GROUP = LOG_GROUPS[1]
LOG_WAIT_SECONDS = 120
LOG_POLL_SECONDS = 5


@pytest.fixture(scope="module")
def logs_client():
    return boto3.client("logs", region_name="eu-west-1")


@pytest.fixture(scope="module")
def probe_user(users_table):
    """
    Seeds a unique user with no photos, so the request is authorized by the authorizer and
    handled (404) by the content lambda, exercising both log groups.
    """
    dni = f"{random.randint(10_000_000, 99_999_999)}{random.choice('TRWAGMYFPDXBNJZSQVHLCKE')}"
    name = f"LogProbe{uuid.uuid4().hex[:12]}"
    users_table.put_item(Item={"username": name, "dnis": [dni]})

    yield {"dni": dni, "name": name}

    users_table.delete_item(Key={"username": name})


def _find_events(logs_client, log_group: str, term: str, start_ms: int) -> list[dict]:
    response = logs_client.filter_log_events(
        logGroupName=log_group,
        startTime=start_ms,
        filterPattern=f'"{term}"',
    )
    return response.get("events", [])


class TestUS005NoPersonalDataInLogs:
    """
    Functional test for US-005.
    """

    def test_credentials_are_not_written_to_logs(self, api_gateway_url, probe_user, logs_client):
        """
        Scenario: A user requests their photos and no personal data is logged
        """
        credentials = f"{probe_user['dni']}:{probe_user['name']}"
        encoded = base64.b64encode(credentials.encode()).decode()
        start_ms = int(time.time() * 1000) - 5_000

        response = requests.get(api_gateway_url, headers={"Authorization": f"Basic {encoded}"})

        assert response.status_code == 404
        request_id = response.headers["x-amzn-RequestId"]

        # Wait until the content lambda's log line for this request is ingested, so the
        # negative assertions below run against a complete set of logs.
        deadline = time.time() + LOG_WAIT_SECONDS
        while not _find_events(logs_client, CONTENT_LOG_GROUP, request_id, start_ms):
            if time.time() > deadline:
                pytest.fail(f"Request {request_id} never appeared in {CONTENT_LOG_GROUP}")
            time.sleep(LOG_POLL_SECONDS)

        for log_group in LOG_GROUPS:
            for term in (probe_user["dni"], probe_user["name"], encoded):
                events = _find_events(logs_client, log_group, term, start_ms)
                assert events == [], f"Personal data found in {log_group}"
