"""
Lambda Authorizer for API Gateway

This authorizer validates requests by decoding a base64-encoded Authorization header
containing DNI:Name pairs and validating against a DynamoDB users table.
"""

import base64
import logging
import os
from typing import Any

import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

USERS_TABLE_NAME = os.environ.get("USERS_TABLE_NAME", "users")


def get_user_from_dynamodb(username: str) -> dict[str, Any] | None:
    """
    Retrieve user from DynamoDB users table.

    Args:
        username: The username to look up

    Returns:
        User item if found, None otherwise
    """
    try:
        # Initialize DynamoDB client lazily to avoid issues during testing
        dynamodb = boto3.resource("dynamodb")
        users_table = dynamodb.Table(USERS_TABLE_NAME)
        response = users_table.get_item(Key={"username": username})
        return response.get("Item")
    except ClientError as e:
        logger.error(f"Error fetching user from DynamoDB: {e}")
        return None


def generate_policy(
    principal_id: str, effect: str, resource: str, context: dict[str, str] | None = None
) -> dict[str, Any]:
    """
    Generate an IAM policy document for API Gateway.

    Args:
        principal_id: The principal user identifier
        effect: Either 'Allow' or 'Deny'
        resource: The ARN of the resource being accessed
        context: Optional context to pass to the API Gateway

    Returns:
        IAM policy document
    """
    policy = {
        "principalId": principal_id,
        "policyDocument": {
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Action": "execute-api:Invoke",
                    "Effect": effect,
                    "Resource": resource,
                }
            ],
        },
    }

    if context:
        policy["context"] = context

    return policy


def lambda_handler(event: dict[str, Any], context: Any) -> dict[str, Any]:
    """
    Lambda authorizer handler function.

    Validates the Authorization header by:
    1. Decoding from base64
    2. Parsing DNI:Name format
    3. Looking up user in DynamoDB
    4. Validating DNI is in user's dnis list

    Args:
        event: Lambda event payload containing authorization header
        context: Lambda context object

    Returns:
        IAM policy document (Allow or Deny)
    """
    method_arn = event.get("methodArn", "")

    # Get authorization header
    auth_header = event.get("authorizationToken")
    if not auth_header:
        logger.warning("Missing authorization header")
        return generate_policy("unknown", "Deny", method_arn)

    # Remove 'Basic' prefix if present
    if auth_header.startswith("Basic "):
        auth_header = auth_header[6:]

    if not auth_header:
        logger.warning("Only Basic authorization supported")
        return generate_policy("unknown", "Deny", method_arn)

    try:
        # Decode base64 authorization header
        decoded_auth = base64.b64decode(auth_header).decode("utf-8")
        logger.info(f"Decoded authorization: {decoded_auth}")

        # Parse DNI:Name format
        if ":" not in decoded_auth:
            logger.warning("Invalid authorization format - missing colon separator")
            return generate_policy("unknown", "Deny", method_arn)

        dni, name = decoded_auth.split(":", 1)

        # Normalize DNI: remove leading zeros and convert to uppercase
        dni = dni.lstrip("0").upper()

        if not dni or not name:
            logger.warning("Invalid authorization format - empty DNI or name")
            return generate_policy("unknown", "Deny", method_arn)

        # Look up user in DynamoDB
        user = get_user_from_dynamodb(name)

        if not user:
            logger.warning(f"User not found: {name}")
            return generate_policy(name, "Deny", method_arn)

        # Validate DNI is in user's dnis list
        user_dnis = user.get("dnis", [])

        if dni not in user_dnis:
            logger.warning(f"DNI {dni} not authorized for user {name}")
            return generate_policy(name, "Deny", method_arn)

        # Authorization successful
        logger.info(f"Authorization successful for user {name} with DNI {dni}")
        return generate_policy(
            name,
            "Allow",
            method_arn,
            context={"username": name, "dni": dni},
        )

    except (base64.binascii.Error, UnicodeDecodeError) as e:
        logger.error(f"Invalid base64 encoding: {e}")
        return generate_policy("unknown", "Deny", method_arn)
    except Exception as e:
        logger.error(f"Unexpected error during authorization: {e}")
        return generate_policy("unknown", "Deny", method_arn)
