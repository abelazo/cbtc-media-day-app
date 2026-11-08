"""
Unit tests for Lambda authorizer.
"""

import base64
import logging
from unittest.mock import patch

import pytest

from services.authorizer.src.handler import lambda_handler


class TestAuthorizerHandler:
    """Unit tests for the Lambda authorizer handler."""

    @patch("services.authorizer.src.handler.get_user_from_dynamodb")
    def test_authorizer_allows_valid_dni_and_name(self, mock_get_user):
        """Test authorizer allows access when DNI is in user's dnis list."""
        # Arrange
        dni = "12345678A"
        name = "JohnDoe"
        auth_string = f"{dni}:{name}"
        encoded_auth = base64.b64encode(auth_string.encode()).decode()

        event = {
            "type": "REQUEST",
            "methodArn": "arn:aws:execute-api:us-east-1:123456789012:abcdef123/test/GET/resource",
            "authorizationToken": f"Basic {encoded_auth}",
        }
        context = {}

        # Mock DynamoDB response
        mock_get_user.return_value = {"username": "JohnDoe", "dnis": ["12345678A", "87654321B"]}

        # Act
        response = lambda_handler(event, context)

        # Assert
        assert response["principalId"] == "JohnDoe"
        assert response["policyDocument"]["Statement"][0]["Effect"] == "Allow"
        assert response["policyDocument"]["Statement"][0]["Resource"] == event["methodArn"]
        mock_get_user.assert_called_once_with("JohnDoe")

    @patch("services.authorizer.src.handler.get_user_from_dynamodb")
    def test_authorizer_denies_invalid_dni(self, mock_get_user):
        """Test authorizer denies access when DNI is not in user's dnis list."""
        # Arrange
        dni = "99999999Z"
        name = "JohnDoe"
        auth_string = f"{dni}:{name}"
        encoded_auth = base64.b64encode(auth_string.encode()).decode()

        event = {
            "type": "REQUEST",
            "methodArn": "arn:aws:execute-api:us-east-1:123456789012:abcdef123/test/GET/resource",
            "authorizationToken": f"Basic {encoded_auth}",
        }
        context = {}

        # Mock DynamoDB response
        mock_get_user.return_value = {"username": "JohnDoe", "dnis": ["12345678A", "87654321B"]}

        # Act
        response = lambda_handler(event, context)

        # Assert
        assert response["principalId"] == "JohnDoe"
        assert response["policyDocument"]["Statement"][0]["Effect"] == "Deny"
        mock_get_user.assert_called_once_with("JohnDoe")

    @patch("services.authorizer.src.handler.get_user_from_dynamodb")
    def test_authorizer_denies_when_user_not_found(self, mock_get_user):
        """Test authorizer denies access when user is not found in DynamoDB."""
        # Arrange
        dni = "12345678A"
        name = "UnknownUser"
        auth_string = f"Basic {dni}:{name}"
        encoded_auth = base64.b64encode(auth_string.encode()).decode()

        event = {
            "type": "REQUEST",
            "methodArn": "arn:aws:execute-api:us-east-1:123456789012:abcdef123/test/GET/resource",
            "authorizationToken": f"Basic {encoded_auth}",
        }
        context = {}

        # Mock DynamoDB response - user not found
        mock_get_user.return_value = None

        # Act
        response = lambda_handler(event, context)

        # Assert
        assert response["principalId"] == "UnknownUser"
        assert response["policyDocument"]["Statement"][0]["Effect"] == "Deny"
        mock_get_user.assert_called_once_with("UnknownUser")

    def test_authorizer_denies_invalid_authorization_format(self):
        """Test authorizer denies access when authorization format is invalid."""
        # Arrange - missing colon separator
        auth_string = "InvalidFormat"
        encoded_auth = base64.b64encode(auth_string.encode()).decode()

        event = {
            "type": "REQUEST",
            "methodArn": "arn:aws:execute-api:us-east-1:123456789012:abcdef123/test/GET/resource",
            "authorizationToken": f"Basic {encoded_auth}",
        }
        context = {}

        # Act
        response = lambda_handler(event, context)

        # Assert
        assert response["principalId"] == "unknown"
        assert response["policyDocument"]["Statement"][0]["Effect"] == "Deny"

    def test_authorizer_denies_missing_authorization_header(self):
        """Test authorizer denies access when authorization header is missing."""
        # Arrange
        event = {
            "type": "REQUEST",
            "methodArn": "arn:aws:execute-api:us-east-1:123456789012:abcdef123/test/GET/resource",
            "headers": {},
        }
        context = {}

        # Act
        response = lambda_handler(event, context)

        # Assert
        assert response["principalId"] == "unknown"
        assert response["policyDocument"]["Statement"][0]["Effect"] == "Deny"

    def test_authorizer_denies_invalid_base64(self):
        """Test authorizer denies access when authorization is not valid base64."""
        # Arrange
        event = {
            "type": "REQUEST",
            "methodArn": "arn:aws:execute-api:us-east-1:123456789012:abcdef123/test/GET/resource",
            "authorizationToken": "Basic Not-Valid-Base64!!!",
        }
        context = {}

        # Act
        response = lambda_handler(event, context)

        # Assert
        assert response["principalId"] == "unknown"
        assert response["policyDocument"]["Statement"][0]["Effect"] == "Deny"

    @patch("services.authorizer.src.handler.get_user_from_dynamodb")
    def test_authorizer_context_includes_user_info(self, mock_get_user):
        """Test authorizer includes user information in context."""
        # Arrange
        dni = "12345678A"
        name = "JohnDoe"
        auth_string = f"{dni}:{name}"
        encoded_auth = base64.b64encode(auth_string.encode()).decode()

        event = {
            "type": "REQUEST",
            "methodArn": "arn:aws:execute-api:us-east-1:123456789012:abcdef123/test/GET/resource",
            "authorizationToken": f"Basic {encoded_auth}",
        }
        context = {}

        # Mock DynamoDB response
        mock_get_user.return_value = {"username": "JohnDoe", "dnis": ["12345678A"]}

        # Act
        response = lambda_handler(event, context)

        # Assert
        assert "context" in response
        assert response["context"]["username"] == "JohnDoe"
        assert response["context"]["dni"] == "12345678A"


METHOD_ARN = "arn:aws:execute-api:us-east-1:123456789012:abcdef123/test/GET/resource"


def _encode(value: str) -> str:
    return base64.b64encode(value.encode()).decode()


class TestAuthorizerDoesNotLogPersonalData:
    """US-005: DNI, name and raw credentials must never be written to the logs."""

    @pytest.mark.parametrize(
        ("credentials", "stored_user"),
        [
            pytest.param("12345678A:JohnDoe", {"username": "JohnDoe", "dnis": ["12345678A"]}, id="allow"),
            pytest.param("99999999Z:JohnDoe", {"username": "JohnDoe", "dnis": ["12345678A"]}, id="wrong-dni"),
            pytest.param("12345678A:JohnDoe", None, id="unknown-user"),
            pytest.param("12345678AJohnDoe", None, id="missing-colon"),
        ],
    )
    @patch("services.authorizer.src.handler.get_user_from_dynamodb")
    def test_credentials_not_logged(self, mock_get_user, caplog, credentials, stored_user):
        caplog.set_level(logging.DEBUG)
        mock_get_user.return_value = stored_user
        encoded = _encode(credentials)

        lambda_handler({"methodArn": METHOD_ARN, "authorizationToken": f"Basic {encoded}"}, {})

        for secret in ("12345678A", "99999999Z", "JohnDoe", credentials, encoded):
            assert secret not in caplog.text

    def test_invalid_utf8_credentials_not_logged(self, caplog):
        caplog.set_level(logging.DEBUG)
        encoded = base64.b64encode(b"\xff12345678A:JohnDoe").decode()

        lambda_handler({"methodArn": METHOD_ARN, "authorizationToken": f"Basic {encoded}"}, {})

        for secret in ("12345678A", "JohnDoe", encoded):
            assert secret not in caplog.text
