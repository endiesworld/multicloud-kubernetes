output "control_plane_public_ip" {
  description = "Public IP address assigned to the Kubernetes control-plane node."
  value       = aws_instance.cp_instance.public_ip
}

output "control_plane_private_ip" {
  description = "Private IP address assigned to the Kubernetes control-plane node."
  value       = aws_instance.cp_instance.private_ip
}

output "control_plane_ssh_target" {
  description = "SSH target for the Kubernetes control-plane node."
  value       = "ec2-user@${aws_instance.cp_instance.public_ip}"
}

output "worker_private_ips" {
  description = "Private IP addresses for the Kubernetes worker nodes."
  value = {
    worker_node_1 = aws_instance.worker_instance_1.private_ip
    worker_node_2 = aws_instance.worker_instance_2.private_ip
  }
}

output "worker_ssh_targets_via_control_plane" {
  description = "Worker SSH targets to use after connecting to the control plane."
  value = {
    worker_node_1 = "ec2-user@${aws_instance.worker_instance_1.private_ip}"
    worker_node_2 = "ec2-user@${aws_instance.worker_instance_2.private_ip}"
  }
}
