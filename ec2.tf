resource "aws_instance" "example" {
  ami                  = "ami-05a03e6058638183d"
  instance_type        = "t2.micro"
  iam_instance_profile = aws_iam_instance_profile.example.name
  tags = {
    Name = "ec2-batch-scheduler-example"
  }
}

resource "aws_iam_instance_profile" "example" {
  role = aws_iam_role.example.name
}

resource "aws_iam_role" "example" {
  name               = "ec2-batch-scheduler-example"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role_policy.json
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    "arn:aws:iam::aws:policy/AmazonSSMPatchAssociation",
    module.scheduler_example.iam_policy_logger_arn,
  ]
}

data "aws_iam_policy_document" "ec2_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}
