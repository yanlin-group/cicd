# Create policy for Codebuild
resource "aws_iam_policy" "codebuild" {
  name        = "CodebuildCIPolicy"
  path        = "/"
  description = "Policy for codebuild required to deploy the app, such access to ecr, and eks"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action = [
          "ecr:*",
          "cloudtrail:LookupEvents"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action = [
          "eks:*"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action = [
          "ssm:GetParameters"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetBucketAcl",
          "s3:GetBucketLocation"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action = [
          "codecommit:GitPull"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action = [
          "codebuild:CreateReportGroup",
          "codebuild:CreateReport",
          "codebuild:UpdateReport",
          "codebuild:BatchPutTestCases",
          "codebuild:BatchPutCodeCoverages"
        ]
        Resource = "*"
      }
    ]
  })
}
# This user will be used to provide credential aws access key id
# and secret in codebuild to manage eks/ecr/kubectl.
resource "aws_iam_user" "codebuild" {
  name = "codebuild"
}
resource "aws_iam_user_policy_attachment" "codebuild" {
  user       = aws_iam_user.codebuild.name
  policy_arn = aws_iam_policy.codebuild.arn
}
# The primary of this resource is for iam role initialization
data "aws_iam_policy_document" "codebuild-assume-role-policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}
# This role is used to run codebuild in console
resource "aws_iam_role" "codebuild" {
  name = "CodebuildRole"
  # This is required by terraform, kind of useless if we use `managed_policy_arns`
  assume_role_policy = data.aws_iam_policy_document.codebuild-assume-role-policy.json
}
resource "aws_iam_role_policy_attachment" "codebuild" {
  role       = aws_iam_role.codebuild.name
  policy_arn = aws_iam_policy.codebuild.arn
}

# The primary of this resource is for iam role initialization
data "aws_iam_policy_document" "codepipeline-assume-role-policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }
  }
}
# This role is used to run codebuild in console
resource "aws_iam_role" "codepipeline" {
  name = "CodepipelineRole"
  # This is required by terraform, kind of useless if we use `managed_policy_arns`
  assume_role_policy = data.aws_iam_policy_document.codepipeline-assume-role-policy.json
}
# Create policy for Codepipeline
resource "aws_iam_policy" "codepipeline" {
  name        = "CodepipelineCIPolicy"
  path        = "/"
  description = "Policy for codepipeline required to deploy the app, such access to ecr, and eks"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action = [
          "codecommit:CancelUploadArchive",
          "codecommit:GetBranch",
          "codecommit:GetCommit",
          "codecommit:GetRepository",
          "codecommit:GetUploadArchiveStatus",
          "codecommit:UploadArchive"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action = [
          "codedeploy:CreateDeployment",
          "codedeploy:GetApplication",
          "codedeploy:GetApplicationRevision",
          "codedeploy:GetDeployment",
          "codedeploy:GetDeploymentConfig",
          "codedeploy:RegisterApplicationRevision"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action = [
          "elasticbeanstalk:*",
          "ec2:*",
          "elasticloadbalancing:*",
          "autoscaling:*",
          "cloudwatch:*",
          "s3:*",
          "sns:*",
          "cloudformation:*",
          "rds:*",
          "sqs:*",
          "ecs:*"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action = [
          "lambda:InvokeFunction",
          "lambda:ListFunctions"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action = [
          "cloudformation:CreateStack",
          "cloudformation:DeleteStack",
          "cloudformation:DescribeStacks",
          "cloudformation:UpdateStack",
          "cloudformation:CreateChangeSet",
          "cloudformation:DeleteChangeSet",
          "cloudformation:DescribeChangeSet",
          "cloudformation:ExecuteChangeSet",
          "cloudformation:SetStackPolicy",
          "cloudformation:ValidateTemplate"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action = [
          "codebuild:BatchGetBuilds",
          "codebuild:StartBuild",
          "codebuild:BatchGetBuildBatches",
          "codebuild:StartBuildBatch"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action = [
          "servicecatalog:ListProvisioningArtifacts",
          "servicecatalog:CreateProvisioningArtifact",
          "servicecatalog:DescribeProvisioningArtifact",
          "servicecatalog:DeleteProvisioningArtifact",
          "servicecatalog:UpdateProduct"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action = [
          "cloudformation:ValidateTemplate"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action = [
          "ecr:DescribeImages"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action = [
          "states:DescribeExecution",
          "states:DescribeStateMachine",
          "states:StartExecution"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action = [
          "appconfig:StartDeployment",
          "appconfig:StopDeployment",
          "appconfig:GetDeployment"
        ]
        Resource = "*"
      }
    ]
  })
}
resource "aws_iam_role_policy_attachment" "codepipeline" {
  role       = aws_iam_role.codepipeline.name
  policy_arn = aws_iam_policy.codepipeline.arn
}
