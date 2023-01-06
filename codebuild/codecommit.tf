# 公众号通知项目 - 后端接口
resource "aws_codecommit_repository" "wechat-official-api" {
  repository_name = "wechat-official-api"
  description     = "微信公众号通知接口"
}