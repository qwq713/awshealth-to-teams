resource "aws_iam_policy" "lambda_policy" {
    name = "AwsHealthToTeamsLambdaPolicy"
    description = "IAM policy"
    policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup"
      ],
      "Resource": "arn:aws:logs:${var.region}:${var.account_id}:*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:${var.region}:${var.account_id}:log-group:/aws/lambda/${var.lambda_function_name}"
    }
  ]
}
EOF
}

resource "aws_iam_role" "iam_for_lambda" {
    name = "${var.lambda_function_name}-role"
    assume_role_policy = <<EOF
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Principal": {
                    "Service": "lambda.amazonaws.com"
                },
                "Action": "sts:AssumeRole"
            }
        ]
    }
    EOF
}

data "archive_file" "lambda" {
    type = "zip"
    source_file = "${var.source_dir}/main.py"
    output_path = "${var.lambda_function_name}.zip"
}

resource "aws_lambda_function" "lambda_function" {
    # If the file is not in the current working directory you will need to include a
    # path.module in the filename.
    filename = "${var.lambda_function_name}.zip"
    function_name = "${var.lambda_function_name}"
    role = aws_iam_role.iam_for_lambda.arn
    handler = "main.lambda_handler"

    source_code_hash = data.archive_file.lambda.output_base64sha256

    runtime = "python3.10"

    environment {
        variables = {
            TEAMS_URL = "${var.teams_url}"
        }
    }
}

resource "aws_iam_role_policy_attachment" "iam_role_policy_attachment" {
    role = aws_iam_role.iam_for_lambda.name
    policy_arn = aws_iam_policy.lambda_policy.arn
}

resource "aws_cloudwatch_event_rule" "awshealth_rule" {
  name        = "cloudwatch-rule-aws-health-to-lambda"
  description = "cloudwatch-rule-aws-health-to-lambda"

  event_pattern = <<EOF
{
  "source": [
    "aws.health"
  ]
}
EOF
}

resource "aws_cloudwatch_event_target" "awshealth_to_teams" {
  arn  = aws_lambda_function.lambda_function.arn
  rule = aws_cloudwatch_event_rule.awshealth_rule.id
}