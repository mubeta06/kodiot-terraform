provider aws {
  region = "${var.region}"
}

provider aws {
  alias  = "usa"
  region = "us-east-1"
}

#######################################
# AWS Lambda
#######################################

data aws_iam_policy_document "kodi_alexa_handler" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource aws_iam_role "kodi_alexa_handler" {
  name               = "kodi-alexa-handler"
  assume_role_policy = "${data.aws_iam_policy_document.kodi_alexa_handler.json}"
}

resource aws_iam_policy "kodi_alexa_handler" {
  name        = "kodi-alexa-handler"
  description = "Basic Execution and Shadow Update."
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "arn:aws:logs:*:*:*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "iot:GetThingShadow",
                "iot:UpdateThingShadow",
                "iot:DeleteThingShadow"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}

resource aws_iam_role_policy_attachment "kodi_alexa_handler" {
  role       = "${aws_iam_role.kodi_alexa_handler.name}"
  policy_arn = "${aws_iam_policy.kodi_alexa_handler.arn}"
}

resource aws_lambda_function "kodi_alexa_handler" {
  provider         = "aws.usa"
  filename         = "${var.lambda_artifact}"
  function_name    = "kodi-alexa-handler"
  role             = "${aws_iam_role.kodi_alexa_handler.arn}"
  handler          = "lambda_function.lambda_handler"
  source_code_hash = "${base64sha256(file("lambda.zip"))}"
  runtime          = "python2.7"
  memory_size      = 1024
  timeout          = 10
}

#######################################
# AWS IoT
#######################################

data aws_iot_endpoint "current" {}

resource aws_iot_thing "kodi" {
  name = "${var.thing}"
}

resource aws_iot_policy "kodi" {
  name        = "Allow${var.thing}"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "iot:Publish",
        "iot:Subscribe",
        "iot:Connect",
        "iot:Receive"
      ],
      "Effect": "Allow",
      "Resource": [
        "*"
      ]
    }
  ]
}
EOF
}

resource null_resource "certificates" {

  triggers {
    thing = "${aws_iot_thing.kodi.arn}"
  }
  
  provisioner "local-exec" {
    command = "aws iot create-keys-and-certificate --set-as-active >> certs"
  }

  provisioner "local-exec" {
    command = "cat certs | jq -r '.[\"certificatePem\"]' > ${var.thing}.cert.pem"
  }

  provisioner "local-exec" {
    command = "cat certs | jq -r '.[\"keyPair\"][\"PrivateKey\"]' > ${var.thing}.private.key"
  }

  provisioner "local-exec" {
    command = "aws iot attach-thing-principal --thing-name ${var.thing} --principal $(cat certs | jq -r '.[\"certificateArn\"]')"
  }

  provisioner "local-exec" {
    command = "aws iot attach-principal-policy --policy-name ${aws_iot_policy.kodi.name} --principal $(cat certs | jq -r '.[\"certificateArn\"]')"
  }

  provisioner "file" {
    source      = "${var.thing}.cert.pem"
    destination = "/home/${var.user}/${var.thing}.cert.pem"

    connection {
      type     = "ssh"
      user     = "${var.user}"
      host     = "${var.host}"
      password = "${var.password}"
    }
  }

  provisioner "file" {
    source      = "${var.thing}.private.key"
    destination = "/home/${var.user}/${var.thing}.private.key"

    connection {
      type     = "ssh"
      user     = "${var.user}"
      host     = "${var.host}"
      password = "${var.password}"
    }
  }

  provisioner "remote-exec" {
    inline = [
      "wget ${var.root_cert_file_url}"
    ]

    connection {
      type     = "ssh"
      user     = "${var.user}"
      host     = "${var.host}"
      password = "${var.password}"
    }
  }

}