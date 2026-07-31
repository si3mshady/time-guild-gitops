output "alb_endpoint" {
  value       = "http://${module.compute.alb_dns_name}"
  description = "Prod ALB DNS Endpoint"
}

output "db_address" {
  value       = module.database.address
  description = "Prod RDS Host address"
}

output "ecr_url" {
  value       = module.compute.ecr_repository_url
  description = "Prod ECR Repository URL"
}
