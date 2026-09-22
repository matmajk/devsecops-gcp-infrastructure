locals {
  database_instance_name   = "${var.name_prefix}-jfrog-db"
  database_name            = "artifactory"
  database_user            = "artifactory"
  filestore_bucket_name    = "${var.project_id}-jfrog-filestore"
  service_account_id       = "${var.name_prefix}-jfrog"
  database_password_secret = "${var.name_prefix}-jfrog-db-password"
  master_key_secret        = "${var.name_prefix}-jfrog-master-key"
  join_key_secret          = "${var.name_prefix}-jfrog-join-key"
}

resource "google_sql_database_instance" "jfrog" {
  project = var.project_id

  name             = local.database_instance_name
  region           = var.region
  database_version = var.database_version

  deletion_protection = false

  settings {
    tier    = var.database_tier
    edition = "ENTERPRISE"

    availability_type = "ZONAL"

    disk_type             = "PD_HDD"
    disk_size             = var.database_disk_size_gb
    disk_autoresize       = true
    disk_autoresize_limit = var.database_disk_autoresize_limit_gb

    ip_configuration {
      ipv4_enabled    = false
      private_network = var.network_id
    }

    backup_configuration {
      enabled = false
    }
  }
}

resource "google_sql_database" "jfrog" {
  project = var.project_id

  name     = local.database_name
  instance = google_sql_database_instance.jfrog.name
}

resource "random_password" "jfrog_database" {
  length  = 32
  special = true
}

resource "google_sql_user" "jfrog" {
  project = var.project_id

  name     = local.database_user
  instance = google_sql_database_instance.jfrog.name
  password = random_password.jfrog_database.result
}

resource "google_secret_manager_secret" "jfrog_database_password" {
  project = var.project_id

  secret_id = local.database_password_secret

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "jfrog_database_password" {
  secret      = google_secret_manager_secret.jfrog_database_password.id
  secret_data = random_password.jfrog_database.result
}

resource "google_secret_manager_secret" "jfrog_master_key" {
  project = var.project_id

  secret_id = local.master_key_secret

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret" "jfrog_join_key" {
  project = var.project_id

  secret_id = local.join_key_secret

  replication {
    auto {}
  }
}

resource "google_storage_bucket" "jfrog_filestore" {
  project = var.project_id

  name     = local.filestore_bucket_name
  location = var.region

  storage_class = "STANDARD"

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  force_destroy = true

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      num_newer_versions = 2
    }

    action {
      type = "Delete"
    }
  }
}

resource "google_service_account" "jfrog" {
  project = var.project_id

  account_id   = local.service_account_id
  display_name = "JFrog Container Registry"
}

resource "google_storage_bucket_iam_member" "jfrog" {
  bucket = google_storage_bucket.jfrog_filestore.name
  role   = "roles/storage.admin"

  member = "serviceAccount:${google_service_account.jfrog.email}"
}

resource "google_service_account_iam_member" "jfrog_workload_identity" {
  service_account_id = google_service_account.jfrog.name

  role = "roles/iam.workloadIdentityUser"

  member = "serviceAccount:${var.project_id}.svc.id.goog[${var.jfrog_namespace}/${var.jfrog_kubernetes_service_account}]"
}

