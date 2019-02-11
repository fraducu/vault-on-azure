#backend configuration for storring tfstate files
 data "terraform_remote_state" "azurerm_remote_state" {
  backend = "azurerm"
  config {
  #  resource_group_name  = "${var.terraform_state_resource_group_name}"
    storage_account_name = "${var.terraform_state_storage_account_name}"
    container_name       = "${var.terraform_state_container_name}"
    access_key           = "${var.terraform_state_access_key}"
    key                  = "ValultDemo.tfstate"
  }
}