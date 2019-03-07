
#Environment variables
variable "AZURE_SUBSCRIPTION_ID" {}
variable "AZURE_CLIENT_ID" {}
variable "AZURE_CLIENT_SECRET" {}
variable "AZURE_TENANT_ID" {} 


variable "location" {
  default = "NorthEurope"
}

variable "resource_group_name" {
  default = "vault"
}

variable "sg_name" {
  description = "security group name"
  default = "cicdvault-nsg"
}

# variable "subnet_prefixes" {
#   default = ["10.0.1.0/24", "10.0.2.0/24"]
# }

# variable "subnet_names" {
#   default = ["azure-vault-demo-public-subnet", "azure-vault-demo-private-subnet"]
# }

# Provisioning script variables

variable "cmd_extension" {
  description = "Command to be excuted by the custom script extension"
  default     = "sh vault-install.sh"
}

variable "cmd_script" {
  description = "Script to download which can be executed by the custom script extension"
  default     = "https://gist.githubusercontent.com/fraducu/d54404e56ae5981a85878697018778bc/raw/2eb89dcbe058f27b26fb534caee03d2b4c0f7e5f/vault-install.sh"
}

variable "vm_admin" {
    description = "vm admin account name"
    //Disallowed values: "administrator", "admin", "user", "user1", "test", "user2", "test1", "user3", "admin1", "1", "123", "a", "actuser", "adm", "admin2", "aspnet", "backup", "console", "david", "guest", "john", "owner", "root", "server", "sql", "support", "support_388945a0", "sys", "test2", "test3", "user4", "user5".
}

#variable "ssh_key_public" {}

#variable "ssh_key_private" {}
