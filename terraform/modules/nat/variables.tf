variable "project_id" {
  description = "Google Cloud project ID."
  type        = string
}

variable "region" {
  description = "Google Cloud region where Cloud NAT is created."
  type        = string
}

variable "name_prefix" {
  description = "Common prefix used for NAT resource names."
  type        = string
}

variable "router_name" {
  description = "Name of the existing Cloud Router."
  type        = string
}

variable "subnetwork_id" {
  description = "ID of the subnetwork whose IP ranges are translated by Cloud NAT."
  type        = string
}