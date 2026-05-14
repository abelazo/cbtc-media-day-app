import os
import pathlib
import subprocess

import boto3
import pytest


@pytest.fixture(scope="module")
def api_gateway_url():
    """
    Get the API Gateway URL from environment or Terraform output.
    """
    url = os.getenv("API_GATEWAY_URL")
    if not url:
        current_dir = pathlib.Path(__file__).parent.absolute()
        infra_dir = current_dir.parent.parent / "infra" / "api-gateway"

        try:
            result = subprocess.run(
                ["terraform", "output", "-raw", "api_gateway_url"],
                cwd=str(infra_dir),
                capture_output=True,
                text=True,
                check=True,
            )
            url = result.stdout.strip()
        except (subprocess.CalledProcessError, FileNotFoundError):
            pytest.skip("API Gateway not deployed. Run infrastructure deployment first.")

    return url


@pytest.fixture(scope="module")
def users_table():
    """
    Get the users table name and ensure it's ready.
    """
    table_name = "users"
    dynamodb = boto3.resource("dynamodb")

    try:
        table = dynamodb.Table(table_name)
        table.load()
    except Exception:
        pass

    return dynamodb.Table(table_name)


@pytest.fixture(scope="module")
def seeded_users(users_table):
    """
    Seed the users table with test data.
    """
    users = [
        {"username": "ValidUser", "dnis": ["12345678A", "87654321B"]},
        {"username": "TestUser", "dnis": ["11111111C"]},
    ]

    try:
        for user in users:
            users_table.put_item(Item=user)
    except Exception as e:
        print(f"Warning: Could not seed table: {e}")

    return users
