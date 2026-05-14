resource "aws_iam_role" "content_lambda" {
  name = "${var.project_name}-${var.environment}-content-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-content-lambda"
  }
}

resource "aws_iam_role_policy_attachment" "content_lambda_basic" {
  role       = aws_iam_role.content_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "content_lambda_s3" {
  name = "${var.project_name}-${var.environment}-content-s3"
  role = aws_iam_role.content_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
        ]
        Resource = [
          data.terraform_remote_state.global.outputs.content_bucket_arn,
          "${data.terraform_remote_state.global.outputs.content_bucket_arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "content_lambda_dynamodb" {
  name = "${var.project_name}-${var.environment}-content-dynamodb"
  role = aws_iam_role.content_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:Scan",
          "dynamodb:PutItem"
        ]
        Resource = data.terraform_remote_state.global.outputs.users_table_arn
      }
    ]
  })
}
