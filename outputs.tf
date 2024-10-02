output "gateway" {
  description = "The gateway resource."
  value       = google_network_services_gateway.gateway
}

output "gateway_security_policy" {
  description = "The gateway security policy resource."
  value       = google_network_services_gateway.gateway.gateway_security_policy
}

output "id" {
  description = "ID of the gateway resource."
  value       = google_network_services_gateway.gateway.id
}
