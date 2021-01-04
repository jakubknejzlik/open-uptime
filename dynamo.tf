resource "aws_dynamodb_table" "monitors" {
  name         = "OpenuptimeMonitors"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = {
    app = "openuptime"
  }
}

resource "aws_iam_role" "monitors" {
  name = "openuptime-monitors"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "appsync.amazonaws.com"
      },
      "Effect": "Allow"
    },
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "monitors" {
  name = "openuptime-monitors"
  role = aws_iam_role.monitors.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "dynamodb:*"
      ],
      "Effect": "Allow",
      "Resource": [
        "${aws_dynamodb_table.monitors.arn}"
      ]
    }
  ]
}
EOF
}

resource "aws_appsync_datasource" "monitors" {
  api_id           = aws_appsync_graphql_api.test.id
  name             = "openuptime_monitors"
  service_role_arn = aws_iam_role.monitors.arn
  type             = "AMAZON_DYNAMODB"

  dynamodb_config {
    table_name = aws_dynamodb_table.monitors.name
  }
}
