resource "google_service_account" "gke_nodes" {
  project = var.project_id

  account_id   = "${var.name_prefix}-gke-nodes"
  display_name = "GKE node service account"
  description  = "Least-privilege service account used by GKE worker nodes."
}

resource "google_project_iam_member" "gke_nodes" {
  project = var.project_id
  role    = "roles/container.defaultNodeServiceAccount"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}