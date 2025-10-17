output "sonarqube_public_ip" {
  description = "Public IP of SonarQube server"
  value       = aws_instance.sonarqube.public_ip
}

output "sonarqube_url" {
  description = "SonarQube web interface URL"
  value       = "http://${aws_instance.sonarqube.public_ip}:9000"
}
