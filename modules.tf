module "scheduler_example" {
  source = "./modules/scheduler"

  env         = "example"
  aws_region  = var.region
  instance_id = aws_instance.example.id
  schedule    = yamldecode(file("./schedule.yml"))
  slack       = var.slack
}
