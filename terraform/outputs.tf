# Output SSH command
output "ssh_command" {
  value = "ssh -i sshkey-${aws_key_pair.tf_key.key_name}.pem ec2-user@${aws_instance.oracle_instance.public_dns}"
}

output "docker_exec_command" {
  description = "Command to log into Oracle DB container via Docker exec"
  value       = "docker exec -it oracle-xe sqlplus system/Welcome1@localhost:1521/XE"
}
