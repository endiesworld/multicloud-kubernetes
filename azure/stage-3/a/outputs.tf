output "public_ip" {
  description = "The public IP address of the virtual machine."
  value       = azurerm_public_ip.pip.ip_address
}