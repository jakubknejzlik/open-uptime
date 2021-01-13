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

resource "aws_dynamodb_table" "events" {
  name           = "OpenuptimeEvents"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"
  range_key = "monitorId"
  attribute {
    name = "id"
    type = "S"
  }
  attribute {
    name = "monitorId"
    type = "S"
  }
  attribute {
    name = "date"
    type = "S"
  }
  # attribute {
  #   name = "state"
  #   type = "S"
  # }

  global_secondary_index {
    name = "test"
    hash_key ="monitorId"
    range_key = "date"
    projection_type = "ALL"
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
