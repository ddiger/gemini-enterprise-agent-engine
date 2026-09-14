# Model Armor Floor Setting & DLP Inspection Templates

resource "google_data_loss_prevention_inspect_template" "ssn_inspect_template" {
  parent       = "projects/${var.project_id}/locations/${var.region}"
  description  = "Cloud DLP Inspection Template for SSN and Financial PII"
  display_name = "SSN-Financial-Inspect-Template"

  inspect_config {
    info_types {
      name = "US_SOCIAL_SECURITY_NUMBER"
    }
    info_types {
      name = "CREDIT_CARD_NUMBER"
    }
    min_likelihood = "LIKELY"
    limits {
      max_findings_per_request = 100
    }
  }
}

resource "google_data_loss_prevention_deidentify_template" "ssn_mask_template" {
  parent       = "projects/${var.project_id}/locations/${var.region}"
  description  = "De-identification template replacing SSN with redaction tags"
  display_name = "SSN-Mask-Deidentify-Template"

  deidentify_config {
    info_type_transformations {
      transformations {
        info_types {
          name = "US_SOCIAL_SECURITY_NUMBER"
        }
        primitive_transformation {
          replace_with_info_type_config = true
        }
      }
    }
  }
}
