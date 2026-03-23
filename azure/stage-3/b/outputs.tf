output "terraform_vm_public_ip" {
  description = "The public IP address of the first VM module."
  value       = module.terraform-vm.public_ip
}

output "second_terraform_vm_public_ip" {
  description = "The public IP address of the second VM module."
  value       = module.second-terraform-vm.public_ip
}
