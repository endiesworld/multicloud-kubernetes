# output "public_ip" {
#   description = "The public IP address of the virtual machine."
#   value       = azurerm_public_ip.control_plane_pip.ip_address
# }

output "control_plane_ssh_target" {
    description = "SSH target for the Kubernetes control-plane node."
    value       = "azureuser@${azurerm_public_ip.control_plane_pip.ip_address}"
}
