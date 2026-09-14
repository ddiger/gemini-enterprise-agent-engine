terraform {
  required_version = ">= 1.7.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.30.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 5.30.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

# 1. VPC Network & Subnets
resource "google_compute_network" "agent_vpc" {
  name                    = var.vpc_name
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "agent_subnet" {
  name          = "${var.vpc_name}-subnet"
  ip_cidr_range = var.subnet_cidr
  region        = var.region
  network       = google_compute_network.agent_vpc.id
}

# PSC NAT Subnetwork for Agent Gateway Egress
resource "google_compute_subnetwork" "psc_nat_subnet" {
  name          = "${var.vpc_name}-psc-nat"
  ip_cidr_range = var.psc_nat_cidr
  region        = var.region
  network       = google_compute_network.agent_vpc.id
  purpose       = "PRIVATE_SERVICE_CONNECT"
}

# 2. Network Attachment for Managed Agent Gateway
resource "google_compute_network_attachment" "agent_gateway_na" {
  name                  = "agent-gateway-attachment"
  region                = var.region
  description           = "Network attachment bridging Agent Gateway to Enterprise VPC"
  connection_preference = "ACCEPT_AUTOMATIC"
  subnetworks           = [google_compute_subnetwork.psc_nat_subnet.id]
}

# 3. Service Account for Agent Runtime
resource "google_service_account" "agent_runtime_sa" {
  account_id   = "mortgage-evaluator-sa"
  display_name = "Mortgage Evaluator Agent Runtime Identity"
}

# 4. Service Account for Agent Gateway Proxy
resource "google_service_account" "agent_gateway_sa" {
  account_id   = "agent-gateway-proxy-sa"
  display_name = "Managed Agent Gateway Envoy Identity"
}

# 5. Service Extensions WASM Plugin for Content Inspection
resource "google_network_services_wasm_plugin" "model_armor_wasm" {
  provider    = google-beta
  name        = "model-armor-interceptor"
  location    = var.region
  description = "Envoy WASM plugin for dynamic Model Armor callouts & DLP sanitization"
  main_version = "v1"
}
