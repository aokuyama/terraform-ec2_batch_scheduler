variable "region" {
  type    = string
  default = "ap-northeast-1"
}
variable "slack" {
  type = object({
    team_id    = string
    channel_id = string
  })
}
