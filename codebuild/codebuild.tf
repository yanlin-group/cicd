
# 微信公众号通知接口
resource "aws_codebuild_project" "wechat-official-api" {
  name               = "wechat-official-api"
  build_timeout      = "60"
  queued_timeout     = "480"
  project_visibility = "PRIVATE"
  service_role       = aws_iam_role.codebuild.arn

  # InvalidInputException: Unknown Operation UpdateProjectVisibility
  # https://github.com/hashicorp/terraform-provider-aws/issues/22473
  lifecycle {
    ignore_changes = [project_visibility]
  }

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:4.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "codebuild-group"
      stream_name = "codebuild-stream"
    }
  }

  cache {
    type     = "LOCAL"
    modes    = [ "LOCAL_SOURCE_CACHE", "LOCAL_DOCKER_LAYER_CACHE" ]
  }

  source {
    type            = "CODECOMMIT"
    buildspec       = "codepipeline/buildspec.yml"
    location        = aws_codecommit_repository.wechat-official-api.clone_url_http
    git_clone_depth = 0
  }

  source_version = "refs/heads/${var.code_git_branch}"
}