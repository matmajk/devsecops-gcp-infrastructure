output "database_instance_name" {
  description = "JFrog Cloud SQL instance name"
  value       = google_sql_database_instance.jfrog.name
}

output "database_connection_name" {
  description = "JFrog Cloud SQL connection name"
  value       = google_sql_database_instance.jfrog.connection_name
}

output "database_private_ip" {
  description = "JFrog Cloud SQL private IP address"
  value       = google_sql_database_instance.jfrog.private_ip_address
}

output "database_name" {
  description = "JFrog PostgreSQL database name"
  value       = google_sql_database.jfrog.name
}

output "database_user" {
  description = "JFrog PostgreSQL database user"
  value       = google_sql_user.jfrog.name
}

output "database_password_secret_id" {
  description = "Secret Manager secret containing the JFrog database password"
  value       = google_secret_manager_secret.jfrog_database_password.secret_id
}

output "master_key_secret_id" {
  description = "Secret Manager secret used for the JFrog master key"
  value       = google_secret_manager_secret.jfrog_master_key.secret_id
}

output "join_key_secret_id" {
  description = "Secret Manager secret used for the JFrog join key"
  value       = google_secret_manager_secret.jfrog_join_key.secret_id
}

output "filestore_bucket_name" {
  description = "GCS bucket used as the JFrog filestore"
  value       = google_storage_bucket.jfrog_filestore.name
}

output "service_account_email" {
  description = "Google Service Account used by JFrog"
  value       = google_service_account.jfrog.email
}