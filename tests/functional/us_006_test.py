"""
Functional test for US-006: The API only serves the club app and is rate limited.

Makes real requests to the deployed API Gateway and reads the deployed stage configuration.
"""

import base64
import os
import uuid
from urllib.parse import urlparse

import boto3
import pytest
import requests

STAGE_NAME = "v1"
THROTTLE_RATE_LIMIT = 10
THROTTLE_BURST_LIMIT = 50


@pytest.fixture(scope="module")
def app_origin():
    """Frontend origin the API must allow, same value as the APP_URL secret / .env entry."""
    origin = os.getenv("APP_URL")
    if not origin:
        pytest.skip("APP_URL not set. Define it in .env (loaded by just).")
    return origin


@pytest.fixture(scope="module")
def probe_user(users_table):
    """Seeds a unique user with no photos, so the request reaches the content lambda (404)."""
    dni = "12345678Z"
    name = f"CorsProbe{uuid.uuid4().hex[:12]}"
    users_table.put_item(Item={"username": name, "dnis": [dni]})

    yield {"dni": dni, "name": name}

    users_table.delete_item(Key={"username": name})


@pytest.fixture(scope="module")
def rest_api_id(api_gateway_url):
    # https://<rest_api_id>.execute-api.<region>.amazonaws.com/v1/content
    return urlparse(api_gateway_url).hostname.split(".")[0]


class TestUS006CorsRestrictedToApp:
    """
    Functional test for US-006: CORS.
    """

    def test_preflight_allows_only_app_origin(self, api_gateway_url, app_origin):
        """
        Scenario: Browser preflight from the club app is answered with the app origin only
        """
        response = requests.options(
            api_gateway_url,
            headers={
                "Origin": app_origin,
                "Access-Control-Request-Method": "GET",
                "Access-Control-Request-Headers": "authorization",
            },
        )

        assert response.status_code == 200
        assert response.headers["Access-Control-Allow-Origin"] == app_origin
        allowed_methods = {m.strip() for m in response.headers["Access-Control-Allow-Methods"].split(",")}
        assert allowed_methods == {"GET", "OPTIONS"}
        allowed_headers = {h.strip().lower() for h in response.headers["Access-Control-Allow-Headers"].split(",")}
        assert allowed_headers == {"authorization", "content-type"}

    def test_content_response_allows_only_app_origin(self, api_gateway_url, app_origin, probe_user):
        """
        Scenario: Content responses carry the app origin, not a placeholder or wildcard
        """
        credentials = f"{probe_user['dni']}:{probe_user['name']}"
        encoded = base64.b64encode(credentials.encode()).decode()

        response = requests.get(api_gateway_url, headers={"Origin": app_origin, "Authorization": f"Basic {encoded}"})

        # Authorized user without photos: answered by the content lambda
        assert response.status_code == 404
        assert response.headers["Access-Control-Allow-Origin"] == app_origin

    def test_authorizer_deny_allows_app_origin(self, api_gateway_url, app_origin, probe_user):
        """
        Scenario: A denied request is answered by API Gateway with the app origin, so the app can read the 403
        """
        credentials = f"99999999X:{probe_user['name']}"
        encoded = base64.b64encode(credentials.encode()).decode()

        response = requests.get(api_gateway_url, headers={"Origin": app_origin, "Authorization": f"Basic {encoded}"})

        assert response.status_code == 403
        assert response.headers.get("Access-Control-Allow-Origin") == app_origin

    def test_missing_credentials_allows_app_origin(self, api_gateway_url, app_origin):
        """
        Scenario: A request without credentials is answered by API Gateway with the app origin, so the app can read
        the 401
        """
        response = requests.get(api_gateway_url, headers={"Origin": app_origin})

        assert response.status_code == 401
        assert response.headers.get("Access-Control-Allow-Origin") == app_origin


class TestUS006StageThrottling:
    """
    Functional test for US-006: Throttling.
    """

    def test_stage_has_throttling_configured(self, rest_api_id):
        """
        Scenario: The API stage caps request rate and burst for every method
        """
        stage = boto3.client("apigateway", region_name="eu-west-1").get_stage(
            restApiId=rest_api_id, stageName=STAGE_NAME
        )

        settings = stage["methodSettings"]["*/*"]
        assert settings["throttlingRateLimit"] == THROTTLE_RATE_LIMIT
        assert settings["throttlingBurstLimit"] == THROTTLE_BURST_LIMIT
