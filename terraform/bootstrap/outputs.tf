output "state_bucket_name" {
  description = "Name of the Cloud Storage bucket used for Terraform state."
  value       = google_storage_bucket.terraform_state.name
}

output "state_bucket_location" {
  description = "Location of the Terraform state bucket."
  value       = google_storage_bucket.terraform_state.location
}