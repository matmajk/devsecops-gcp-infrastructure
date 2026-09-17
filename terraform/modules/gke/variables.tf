variable "project_id" {
  description = "Google Cloud project ID."
  type        = string
}

variable "region" {
  description = "Region hosting the GKE control plane."
  type        = string
}

variable "name_prefix" {
  description = "Common prefix used for GKE resource names."
  type        = string
}

variable "network_id" {
  description = "ID of the VPC network used by GKE."
  type        = string
}

variable "subnetwork_id" {
  description = "ID of the regional subnetwork used by GKE."
  type        = string
}

variable "pods_secondary_range_name" {
  description = "Secondary subnet range used for Pod IP addresses."
  type        = string
}

variable "services_secondary_range_name" {
  description = "Secondary subnet range used for Kubernetes Service IP addresses."
  type        = string
}

variable "node_service_account_email" {
  description = "Service account used by GKE worker nodes."
  type        = string
}

variable "node_locations" {
  description = "Zones used by the regional GKE node pool."
  type        = list(string)
}

variable "machine_type" {
  description = "Compute Engine machine type used by GKE nodes."
  type        = string
}

variable "node_disk_type" {
  description = "Persistent Disk type used for GKE worker node boot disks."
  type        = string

  validation {
    condition = contains([
      "pd-standard",
      "pd-balanced",
      "pd-ssd",
    ], var.node_disk_type)

    error_message = "node_disk_type must be pd-standard, pd-balanced, or pd-ssd."
  }
}

variable "node_disk_size_gb" {
  description = "Persistent disk size assigned to each GKE worker node."
  type        = number
}

variable "master_ipv4_cidr" {
  description = "CIDR range reserved for the GKE control plane."
  type        = string

  validation {
    condition     = can(cidrhost(var.master_ipv4_cidr, 0))
    error_message = "master_ipv4_cidr must be a valid CIDR range."
  }
}

variable "control_plane_authorized_cidr" {
  description = "CIDR allowed to access the public GKE control plane endpoint."
  type        = string

  validation {
    condition     = can(cidrhost(var.control_plane_authorized_cidr, 0))
    error_message = "control_plane_authorized_cidr must be a valid CIDR range."
  }
}