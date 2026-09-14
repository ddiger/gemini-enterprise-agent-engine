variable "project_id" {
  description = "Target Google Cloud project ID"
  type        = string
}

variable "region" {
  description = "Google Cloud region for resources"
  type        = string
  default     = "us-central1"
}

variable "vpc_name" {
  description = "Name of the Enterprise VPC network"
  type        = string
  default     = "enterprise-agent-vpc"
}

variable "subnet_cidr" {
  description = "CIDR range for primary agent subnet"
  type        = string
  default     = "10.10.0.0/24"
}

variable "psc_nat_cidr" {
  description = "CIDR range for PSC NAT subnetwork"
  type        = string
  default     = "10.20.0.0/24"
}
