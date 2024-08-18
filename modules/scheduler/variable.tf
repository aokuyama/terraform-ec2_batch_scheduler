
variable "env" { type = string }
variable "aws_region" { type = string }
variable "instance_id" { type = string }
variable "slack" {
  type = object({
    team_id = string
    channel_id = object({
      success = string
      error   = string
    })
  })
}
