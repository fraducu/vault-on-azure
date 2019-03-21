 terraform {
   backend "azurerm" {}
 }

resource "azurerm_resource_group" "default" {
  name     = "${var.resource_group_name}"
  location = "${var.location}"

  tags {
    environment = "dev"
    purpose = "CI/CD"
  }
}

data "azurerm_resource_group" "res_group_netw" {
  name = "openshift"
}

# module "network" "vault-demo-network" {
#   source              = "github.com/nicholasjackson/terraform-azurerm-network"
#   location            = "${var.location}"
#   resource_group_name = "${azurerm_resource_group.default.name}"
#   subnet_prefixes     = "${var.subnet_prefixes}"
#   subnet_names        = "${var.subnet_names}"
#   vnet_name           = "tfaz-vnet"
#   sg_name             = "${var.sg_name}"
# }

data "azurerm_virtual_network" "vault-demo-network" {
  name                = "k8s-vNet01"
  resource_group_name = "${data.azurerm_resource_group.res_group_netw.name}"
}

data "azurerm_subnet" "manag" {
  name                 = "Management"
  virtual_network_name = "${data.azurerm_virtual_network.vault-demo-network.name}"
  resource_group_name  = "${data.azurerm_resource_group.res_group_netw.name}"
} 

# resource "azurerm_public_ip" "vault-demo" {
#   name                         = "vault-demo-public-ip"
#   location                     = "${var.location}"
#   resource_group_name          = "${azurerm_resource_group.default.name}"
#   public_ip_address_allocation = "static"
#   domain_name_label            = "${var.resource_group_name}-ssh"

#   tags {
#     environment = "dev"
#   }
# }



resource "azurerm_network_security_group" "vault-demo" {
  name                = "${var.sg_name}"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.default.name}"
}

resource "azurerm_network_security_rule" "ssh_access" {
  name                        = "ssh-access-rule"
  network_security_group_name = "${azurerm_network_security_group.vault-demo.name}"
  direction                   = "Inbound"
  access                      = "Allow"
  priority                    = 200
  source_address_prefix       = "*"
  source_port_range           = "*"
  destination_address_prefix  = "${azurerm_network_interface.vault-demo.private_ip_address}"
  destination_port_range      = "22"
  protocol                    = "TCP"
  resource_group_name         = "${azurerm_resource_group.default.name}"
}

resource "azurerm_network_security_rule" "http_access_vault_demo" {
  name                        = "allow-vault-demo-http"
  direction                   = "Inbound"
  access                      = "Allow"
  priority                    = 210
  source_address_prefix       = "*"
  source_port_range           = "*"
  destination_address_prefix  = "${azurerm_network_interface.vault-demo.private_ip_address}"
  destination_port_range      = "8200"
  protocol                    = "Tcp"
  resource_group_name         = "${azurerm_resource_group.default.name}"
  network_security_group_name = "${var.sg_name}"
}

resource "azurerm_network_interface" "vault-demo" {
  name                      = "vault-demo-nic-0"
  location                  = "${var.location}"
  resource_group_name       = "${azurerm_resource_group.default.name}"
  network_security_group_id = "${azurerm_network_security_group.vault-demo.id}"

  ip_configuration {
    name                          = "IPConfiguration"
    subnet_id                     = "${data.azurerm_subnet.manag.id}"
    private_ip_address_allocation = "dynamic"
    # public_ip_address_id          = "${azurerm_public_ip.vault-demo.id}"
  }

  tags {
    environment = "dev"
  }
}

resource "tls_private_key" "key" {
  algorithm   = "RSA"
}

resource "null_resource" "save-key" {
  triggers {
    key = "${tls_private_key.key.private_key_pem}"
  }

  provisioner "local-exec" {
    command = <<EOF
      mkdir -p ${path.module}/.ssh
      echo "${tls_private_key.key.private_key_pem}" > ${path.module}/.ssh/id_rsa
      chmod 0600 ${path.module}/.ssh/id_rsa
EOF
  }
}

data "template_file" "setup" {
  template = "${file("${path.module}/setup.tpl")}"
}

resource "azurerm_virtual_machine" "vault-demo" {
  name                          = "vault-demo"
  location                      = "${var.location}"
  resource_group_name           = "${azurerm_resource_group.default.name}"
  network_interface_ids         = ["${azurerm_network_interface.vault-demo.id}"]
  vm_size                       = "Standard_B1ms"
  delete_os_disk_on_termination = true
  delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "vault-demo-osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "vault-demo"
    admin_username = "${var.vm_admin}"
    admin_password = "Password1234!"
    custom_data = "${data.template_file.setup.rendered}"
  }

  os_profile_linux_config {
    disable_password_authentication = true

    ssh_keys {
      path     = "/home/${var.vm_admin}/.ssh/authorized_keys"
      key_data = "${trimspace(tls_private_key.key.public_key_openssh)} ${var.vm_admin}@vaultdemo.io"
    }
  }

  identity = {
    type = "SystemAssigned"
  }

  tags {
    environment = "dev"
    purpose = "CI/CD"
  }
}

# resource "azurerm_virtual_machine_extension" "vault-demo" {
#   name                  = "vault-demo-extension"
#   location              = "${var.location}"
#   resource_group_name   = "${azurerm_resource_group.default.name}"
#   virtual_machine_name  = "${azurerm_virtual_machine.vault-demo.name}"
#   publisher             = "Microsoft.OSTCExtensions"
#   type                  = "CustomScriptForLinux"
#   type_handler_version  = "1.2"



#   settings             = <<SETTINGS
#     {
#       "commandToExecute": "${var.cmd_extension}",
#        "fileUris": [
#         "${var.cmd_script}"
#        ]
#     }
# SETTINGS
# }

# # Gets the current subscription id
# data "azurerm_subscription" "primary" {}

# resource "azurerm_role_assignment" "vault-demo" {
#   scope                = "${data.azurerm_subscription.primary.id}"
#   role_definition_name = "Reader"
#   principal_id         = "${lookup(azurerm_virtual_machine.vault-demo.identity[0], "principal_id")}"
# }

