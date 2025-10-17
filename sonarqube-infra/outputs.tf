output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.sonarqube.id
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.sonarqube.public_ip
}

output "instance_public_dns" {
  description = "Public DNS name of the EC2 instance"
  value       = aws_instance.sonarqube.public_dns
}

output "sonarqube_url" {
  description = "URL to access SonarQube web interface"
  value       = "http://${aws_instance.sonarqube.public_ip}:9000"
}

output "security_group_id" {
  description = "ID of the security group"
  value       = aws_security_group.sonarqube_sg.id
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i <your-key.pem> ec2-user@${aws_instance.sonarqube.public_ip}"
}
