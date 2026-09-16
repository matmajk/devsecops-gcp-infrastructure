variable "project_id" {
  description = "Google Cloud project ID where APIs will be enabled."
  type        = string
}

variable "services" {
  description = "Google Cloud APIs enabled for the project."
  type        = set(string)
}