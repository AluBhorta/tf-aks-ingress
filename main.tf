
/* providers.tf */

terraform {
  required_version = ">=1.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.52.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~>2.19.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~>2.9.0"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

/* variables.tf */
variable "resource_group_name" {
  default = "myResourceGroup"
}

variable "location" {
  default = "eastus"
}

variable "aks_cluster_name" {
  default = "myAKSCluster"
}

variable "helm_nginx_ingress_version" {
  default = "4.0.13"
}

/* main.tf */
resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_kubernetes_cluster" "this" {
  name                = var.aks_cluster_name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  dns_prefix          = var.aks_cluster_name

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_DS2_v2"
  }

  identity {
    type = "SystemAssigned"
  }
}

data "azurerm_kubernetes_cluster" "aks" {
  name                = azurerm_kubernetes_cluster.this.name
  resource_group_name = azurerm_resource_group.this.name
}

resource "local_file" "kubeconfig" {
  content  = data.azurerm_kubernetes_cluster.aks.kube_config_raw
  filename = "~/.kube/config"
}

resource "helm_release" "nginx_ingress" {
  depends_on = [local_file.kubeconfig]

  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = var.helm_nginx_ingress_version
  namespace  = "ingress-basic"

  set {
    name  = "controller.service.type"
    value = "LoadBalancer"
  }
}

output "aks_cluster_name" {
  value = azurerm_kubernetes_cluster.this.name
}

output "aks_kube_config" {
  sensitive = true
  value     = data.azurerm_kubernetes_cluster.aks.kube_config_raw
}

output "aks_cluster_ca_certificate" {
  value = data.azurerm_kubernetes_cluster.aks.kube_config.0.cluster_ca_certificate
}

output "aks_host" {
  value = data.azurerm_kubernetes_cluster.aks.kube_config.0.host
}

output "ingress_nginx_version" {
  value = var.helm_nginx_ingress_version
}
