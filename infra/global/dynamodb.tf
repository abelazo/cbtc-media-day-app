resource "aws_dynamodb_table" "users" {
  #checkov:skip=CKV_AWS_28:No backup is acceptable for this table as it only contains non-critical user data that can be recreated if needed
  #checkov:skip=CKV_AWS_119:AWS-managed encryption is acceptable

  name         = "users"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "username"

  attribute {
    name = "username"
    type = "S"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-users"
  }
}
