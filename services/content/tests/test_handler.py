"""
Unit tests for content service handler.
"""

import base64
import json
import logging
import os
from unittest.mock import MagicMock, patch

import pytest

from services.content.src.handler import lambda_handler


@pytest.fixture
def mock_env_vars():
    """Mock environment variables."""
    with patch.dict(
        os.environ,
        {
            "USERS_TABLE_NAME": "test-users",
            "CONTENT_BUCKET_NAME": "test-bucket",
            "CBTC_APP_URL": "https://test-app.com",
        },
    ):
        yield


class TestContentServiceHandler:
    """Unit tests for the Lambda handler."""

    @patch("boto3.resource")
    @patch("boto3.client")
    def test_us004_retrieve_file_success(self, mock_boto_client, mock_boto_resource, mock_env_vars):
        """
        US-004: Retrieve file associated with DNI:Nombre.
        Creates ZIP, uploads to S3, and returns presigned URL.
        """
        dni = "12345678A"
        name = "TestUser"
        credentials = f"{dni}:{name}"
        encoded_auth = base64.b64encode(credentials.encode()).decode()
        event = {"headers": {"Authorization": f"Basic {encoded_auth}"}}
        context = {}

        # Mock DynamoDB
        mock_dynamo = MagicMock()
        mock_boto_resource.return_value = mock_dynamo
        mock_table = MagicMock()
        mock_dynamo.Table.return_value = mock_table
        mock_table.get_item.return_value = {
            "Item": {"photos": ["TestUser/photo1.jpg", "TestUser/photo2.jpg", "TestUser/photo3.jpg"]}
        }

        # Mock S3
        mock_s3 = MagicMock()
        mock_boto_client.return_value = mock_s3
        mock_s3.exceptions = MagicMock()
        mock_s3.exceptions.NoSuchKey = type("NoSuchKey", (Exception,), {})

        # ZIP does not exist yet (cache miss)
        from botocore.exceptions import ClientError

        mock_s3.head_object.side_effect = ClientError({"Error": {"Code": "404"}}, "HeadObject")

        photo_contents = {
            "TestUser/photo1.jpg": b"fake_image_content_1",
            "TestUser/photo2.jpg": b"fake_image_content_2",
            "TestUser/photo3.jpg": b"fake_image_content_3",
        }

        def get_object_side_effect(Bucket, Key):
            return {"Body": MagicMock(read=lambda: photo_contents[Key])}

        mock_s3.get_object.side_effect = get_object_side_effect
        mock_s3.generate_presigned_url.return_value = (
            "https://test-bucket.s3.amazonaws.com/downloads/TestUser.zip?signed"
        )

        response = lambda_handler(event, context)

        assert response["statusCode"] == 200
        body = json.loads(response["body"])
        assert body["success"] is True
        assert "download_url" in body
        assert "TestUser.zip" in body["download_url"]

        # Verify ZIP was uploaded to S3 at downloads/TestUser.zip
        mock_s3.put_object.assert_called_once()
        put_call = mock_s3.put_object.call_args
        assert put_call.kwargs["Bucket"] == "test-bucket"
        assert put_call.kwargs["Key"] == "downloads/TestUser.zip"
        assert put_call.kwargs["ContentType"] == "application/zip"

        # Verify presigned URL was generated
        mock_s3.generate_presigned_url.assert_called_once_with(
            "get_object",
            Params={
                "Bucket": "test-bucket",
                "Key": "downloads/TestUser.zip",
                "ResponseContentDisposition": "attachment; filename=TestUser.zip",
            },
            ExpiresIn=3600,
        )

        # Verify S3 calls for all photos
        assert mock_s3.get_object.call_count == 3

        # Verify DynamoDB call
        mock_table.get_item.assert_called_with(Key={"username": f"{name}"})

    @patch("boto3.resource")
    @patch("boto3.client")
    def test_us004_cached_zip_returns_presigned_url(self, mock_boto_client, mock_boto_resource, mock_env_vars):
        """
        US-004: When ZIP already exists in downloads/, return presigned URL without rebuilding.
        """
        credentials = "12345678A:TestUser"
        encoded_auth = base64.b64encode(credentials.encode()).decode()
        event = {"headers": {"Authorization": f"Basic {encoded_auth}"}}

        # Mock DynamoDB
        mock_dynamo = MagicMock()
        mock_boto_resource.return_value = mock_dynamo
        mock_table = MagicMock()
        mock_dynamo.Table.return_value = mock_table
        mock_table.get_item.return_value = {"Item": {"photos": ["TestUser/photo1.jpg"]}}

        # Mock S3 - ZIP already exists (cache hit)
        mock_s3 = MagicMock()
        mock_boto_client.return_value = mock_s3
        mock_s3.head_object.return_value = {"ContentLength": 12345}
        mock_s3.generate_presigned_url.return_value = (
            "https://test-bucket.s3.amazonaws.com/downloads/TestUser.zip?signed"
        )

        response = lambda_handler(event, {})

        assert response["statusCode"] == 200
        body = json.loads(response["body"])
        assert body["success"] is True
        assert "download_url" in body

        # Verify no ZIP creation happened (no get_object or put_object calls)
        mock_s3.get_object.assert_not_called()
        mock_s3.put_object.assert_not_called()

        # Verify presigned URL was still generated
        mock_s3.generate_presigned_url.assert_called_once()

    @patch("boto3.resource")
    def test_us004_no_photos_found(self, mock_boto_resource, mock_env_vars):
        """
        US-004: Handle no photos found.
        """
        credentials = "87654321B:NoPhoto"
        encoded_auth = base64.b64encode(credentials.encode()).decode()
        event = {"headers": {"Authorization": f"Basic {encoded_auth}"}}
        context = {}

        mock_dynamo = MagicMock()
        mock_boto_resource.return_value = mock_dynamo
        mock_table = MagicMock()
        mock_dynamo.Table.return_value = mock_table

        mock_table.get_item.return_value = {}

        response = lambda_handler(event, context)

        assert response["statusCode"] == 404
        body = json.loads(response["body"])
        assert body["message"] == "No photos associated to this player"

    @patch("boto3.resource")
    def test_us004_dynamodb_error(self, mock_boto_resource, mock_env_vars):
        """US-004: Handle DynamoDB error."""
        credentials = "Error:User"
        encoded_auth = base64.b64encode(credentials.encode()).decode()
        event = {"headers": {"Authorization": f"Basic {encoded_auth}"}}

        mock_dynamo = MagicMock()
        mock_boto_resource.return_value = mock_dynamo
        mock_table = MagicMock()
        mock_dynamo.Table.return_value = mock_table
        mock_table.get_item.side_effect = Exception("DynamoError")

        response = lambda_handler(event, {})

        assert response["statusCode"] == 500
        # No error details are returned to the client
        assert response["body"] == ""

    @patch("boto3.resource")
    @patch("boto3.client")
    def test_us004_partial_success_some_photos_missing(self, mock_boto_client, mock_boto_resource, mock_env_vars):
        """US-004: Handle partial success when some photos are missing from S3."""
        credentials = "12345678A:TestUser"
        encoded_auth = base64.b64encode(credentials.encode()).decode()
        event = {"headers": {"Authorization": f"Basic {encoded_auth}"}}
        context = {}

        mock_dynamo = MagicMock()
        mock_boto_resource.return_value = mock_dynamo
        mock_table = MagicMock()
        mock_dynamo.Table.return_value = mock_table
        mock_table.get_item.return_value = {
            "Item": {"photos": ["TestUser/photo1.jpg", "TestUser/photo2.jpg", "TestUser/photo3.jpg"]}
        }

        mock_s3 = MagicMock()
        mock_boto_client.return_value = mock_s3
        mock_s3.exceptions = MagicMock()
        mock_s3.exceptions.NoSuchKey = type("NoSuchKey", (Exception,), {})

        # Cache miss
        from botocore.exceptions import ClientError

        mock_s3.head_object.side_effect = ClientError({"Error": {"Code": "404"}}, "HeadObject")

        photo_contents = {
            "TestUser/photo1.jpg": b"content_1",
            "TestUser/photo3.jpg": b"content_3",
        }

        def get_object_side_effect(Bucket, Key):
            if Key not in photo_contents:
                raise mock_s3.exceptions.NoSuchKey("The specified key does not exist.")
            return {"Body": MagicMock(read=lambda: photo_contents[Key])}

        mock_s3.get_object.side_effect = get_object_side_effect
        mock_s3.generate_presigned_url.return_value = "https://signed-url"

        response = lambda_handler(event, context)

        assert response["statusCode"] == 200
        body = json.loads(response["body"])
        assert body["success"] is True
        assert "download_url" in body

        # Verify ZIP was uploaded
        mock_s3.put_object.assert_called_once()

    @patch("boto3.resource")
    @patch("boto3.client")
    def test_us004_all_photos_missing(self, mock_boto_client, mock_boto_resource, mock_env_vars):
        """US-004: Return 404 when all photos are missing from S3."""
        credentials = "12345678A:TestUser"
        encoded_auth = base64.b64encode(credentials.encode()).decode()
        event = {"headers": {"Authorization": f"Basic {encoded_auth}"}}
        context = {}

        mock_dynamo = MagicMock()
        mock_boto_resource.return_value = mock_dynamo
        mock_table = MagicMock()
        mock_dynamo.Table.return_value = mock_table
        mock_table.get_item.return_value = {"Item": {"photos": ["TestUser/photo1.jpg", "TestUser/photo2.jpg"]}}

        mock_s3 = MagicMock()
        mock_boto_client.return_value = mock_s3
        mock_s3.exceptions = MagicMock()
        mock_s3.exceptions.NoSuchKey = type("NoSuchKey", (Exception,), {})

        # Cache miss
        from botocore.exceptions import ClientError

        mock_s3.head_object.side_effect = ClientError({"Error": {"Code": "404"}}, "HeadObject")

        mock_s3.get_object.side_effect = mock_s3.exceptions.NoSuchKey("The specified key does not exist.")

        response = lambda_handler(event, context)

        assert response["statusCode"] == 404
        body = json.loads(response["body"])
        assert body["message"] == "No photos associated to this player"

    @patch("boto3.resource")
    @patch("boto3.client")
    def test_us004_s3_error_handling(self, mock_boto_client, mock_boto_resource, mock_env_vars):
        """US-004: Handle S3 errors gracefully and continue processing."""
        credentials = "12345678A:TestUser"
        encoded_auth = base64.b64encode(credentials.encode()).decode()
        event = {"headers": {"Authorization": f"Basic {encoded_auth}"}}
        context = {}

        mock_dynamo = MagicMock()
        mock_boto_resource.return_value = mock_dynamo
        mock_table = MagicMock()
        mock_dynamo.Table.return_value = mock_table
        mock_table.get_item.return_value = {
            "Item": {"photos": ["TestUser/photo1.jpg", "TestUser/photo2.jpg", "TestUser/photo3.jpg"]}
        }

        mock_s3 = MagicMock()
        mock_boto_client.return_value = mock_s3
        mock_s3.exceptions = MagicMock()
        mock_s3.exceptions.NoSuchKey = type("NoSuchKey", (Exception,), {})

        # Cache miss
        from botocore.exceptions import ClientError

        mock_s3.head_object.side_effect = ClientError({"Error": {"Code": "404"}}, "HeadObject")

        call_count = [0]

        def get_object_side_effect(Bucket, Key):
            call_count[0] += 1
            if call_count[0] == 2:
                raise Exception("S3 Service Error")
            content = f"content_{call_count[0]}".encode()
            return {"Body": MagicMock(read=lambda: content)}

        mock_s3.get_object.side_effect = get_object_side_effect
        mock_s3.generate_presigned_url.return_value = "https://signed-url"

        response = lambda_handler(event, context)

        assert response["statusCode"] == 200
        body = json.loads(response["body"])
        assert body["success"] is True
        assert "download_url" in body

        # Verify ZIP was uploaded with only 2 successful photos
        mock_s3.put_object.assert_called_once()


class TestContentDoesNotLogPersonalData:
    """US-005: DNI, name, raw credentials and per-user S3 keys must never be written to the logs."""

    DNI = "12345678A"
    NAME = "TestUser"
    REQUEST_ID = "c0ffee00-1234-5678-9abc-def012345678"

    def _event(self) -> tuple[dict, str]:
        encoded = base64.b64encode(f"{self.DNI}:{self.NAME}".encode()).decode()
        event = {
            "headers": {"Authorization": f"Basic {encoded}"},
            "requestContext": {"requestId": self.REQUEST_ID},
        }
        return event, encoded

    def _mock_aws(self, mock_boto_client, mock_boto_resource, photos, zip_cached=False):
        from botocore.exceptions import ClientError

        mock_table = MagicMock()
        mock_boto_resource.return_value.Table.return_value = mock_table
        mock_table.get_item.return_value = {"Item": {"photos": photos}} if photos else {}

        mock_s3 = MagicMock()
        mock_boto_client.return_value = mock_s3
        mock_s3.exceptions.NoSuchKey = type("NoSuchKey", (Exception,), {})
        if zip_cached:
            mock_s3.head_object.return_value = {}
        else:
            mock_s3.head_object.side_effect = ClientError({"Error": {"Code": "404"}}, "HeadObject")

        def get_object(Bucket, Key):
            if Key.endswith("missing.jpg"):
                raise mock_s3.exceptions.NoSuchKey()
            if Key.endswith("broken.jpg"):
                raise RuntimeError(f"boom on {Key}")
            return {"Body": MagicMock(read=lambda: b"data")}

        mock_s3.get_object.side_effect = get_object
        mock_s3.generate_presigned_url.return_value = "https://signed"

    def _assert_not_logged(self, caplog, encoded):
        for secret in (self.DNI, self.NAME, encoded):
            assert secret not in caplog.text

    @pytest.mark.parametrize(
        ("photos", "zip_cached"),
        [
            pytest.param(["TestUser/photo1.jpg", "TestUser/missing.jpg", "TestUser/broken.jpg"], False, id="build-zip"),
            pytest.param(["TestUser/photo1.jpg"], True, id="cached-zip"),
            pytest.param(["TestUser/missing.jpg"], False, id="all-photos-missing"),
            pytest.param([], False, id="no-photos"),
        ],
    )
    @patch("boto3.resource")
    @patch("boto3.client")
    def test_personal_data_not_logged(
        self, mock_boto_client, mock_boto_resource, mock_env_vars, caplog, photos, zip_cached
    ):
        caplog.set_level(logging.DEBUG)
        self._mock_aws(mock_boto_client, mock_boto_resource, photos, zip_cached)
        event, encoded = self._event()

        lambda_handler(event, {})

        self._assert_not_logged(caplog, encoded)

    @patch("boto3.resource")
    def test_personal_data_not_logged_on_unexpected_error(self, mock_boto_resource, mock_env_vars, caplog):
        caplog.set_level(logging.DEBUG)
        mock_boto_resource.return_value.Table.return_value.get_item.side_effect = Exception(f"boom on {self.NAME}")
        event, encoded = self._event()

        lambda_handler(event, {})

        self._assert_not_logged(caplog, encoded)

    @patch("boto3.resource")
    @patch("boto3.client")
    def test_request_id_is_logged(self, mock_boto_client, mock_boto_resource, mock_env_vars, caplog):
        """The API Gateway request id is logged so a request can be traced without personal data."""
        caplog.set_level(logging.INFO)
        self._mock_aws(mock_boto_client, mock_boto_resource, [])
        event, _ = self._event()

        lambda_handler(event, {})

        assert self.REQUEST_ID in caplog.text
