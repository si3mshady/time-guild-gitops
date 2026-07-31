output "alb_endpoint" {
  value       = "http://${module.compute.alb_dns_name}"
  description = "Dev ALB DNS Endpoint"
}

output "db_address" {
  value       = module.database.address
  description = "Dev RDS Host address"
}

output "ecr_url" {
  value       = module.compute.ecr_repository_url
  description = "Dev ECR Repository URL"
}
