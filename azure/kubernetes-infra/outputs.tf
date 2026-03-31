output "control_plane_public_ip" {
  description = "Public IP address assigned to the Kubernetes control-plane node."
  value       = azurerm_public_ip.control_plane_pip.ip_address
}

output "control_plane_ssh_target" {
  description = "SSH target for the Kubernetes control-plane node."
  value       = "azureuser@${azurerm_public_ip.control_plane_pip.ip_address}"
}

output "worker_private_ips" {
  description = "Private IP addresses for the Kubernetes worker nodes."
  value = {
    worker_node_1 = azurerm_network_interface.nic-worker-plane-1.private_ip_address
    worker_node_2 = azurerm_network_interface.nic-worker-plane-2.private_ip_address
  }
}
