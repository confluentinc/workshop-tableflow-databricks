output "confluent_service_principal_object_id" {
  description = "Object ID of the Confluent multi-tenant service principal"
  value       = azuread_service_principal.confluent.object_id
}
