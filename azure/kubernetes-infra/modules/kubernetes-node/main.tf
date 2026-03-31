resource "azurerm_linux_virtual_machine" "vm" {
  name                = var.node_name
  location            = var.location
  resource_group_name = var.rg_name
  zone                = var.vm_zone
  size                = var.vm_size
  admin_username      = var.admin_username

  network_interface_ids = var.network_interface_ids

  disable_password_authentication = true
  

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(var.public_key_path)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = var.os_disk_storage_account_type
  }

  source_image_reference {
    publisher = var.image_publisher
    offer     = var.image_offer
    sku       = var.image_sku
    version   = var.image_version
  }
  
}