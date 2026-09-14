output "vpc_network_id" {
  description = "ID of the created VPC network"
  value       = google_compute_network.agent_vpc.id
}

output "network_attachment_id" {
  description = "ID of the PSC Network Attachment for Agent Gateway"
  value       = google_compute_network_attachment.agent_gateway_na.id
}

output "agent_runtime_sa_email" {
  description = "Service Account email for Agent Runtime"
  value       = google_service_account.agent_runtime_sa.email
}

output "agent_gateway_sa_email" {
  description = "Service Account email for Agent Gateway"
  value       = google_service_account.agent_gateway_sa.email
}

output "ssn_deidentify_template_id" {
  description = "Cloud DLP de-identify template ID"
  value       = google_data_loss_prevention_deidentify_template.ssn_mask_template.id
}
