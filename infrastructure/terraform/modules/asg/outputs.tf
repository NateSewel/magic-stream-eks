output "asg_id" {
  value = aws_autoscaling_group.main.id
}

output "asg_name" {
  value = aws_autoscaling_group.main.name
}

output "asg_sg_id" {
  value = aws_security_group.asg.id
}
