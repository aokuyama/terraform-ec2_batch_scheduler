resource "aws_dynamodb_table" "state" {
  name           = "${var.env}-sendcommand-to-ec2-state"
  billing_mode   = "PROVISIONED"
  read_capacity  = 1
  write_capacity = 1
  hash_key       = "appCommandId"

  attribute {
    name = "appCommandId"
    type = "S"
  }
}
