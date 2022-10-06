variable "env_name" {
  description = "sandbox, dev, or prod environment"
  type        = string
  validation {
    condition     = contains(["sandbox", "dev", "qa", "stg", "prod"], var.env_name)
    error_message = "Allowed values for input_parameter are \"dev\", \"qa\", \"stg\", \"sandbox\" or \"prod\"."
  }
}

variable "cluster_name" {
  description = "Name of the cluster to create"
  type        = string
}

variable "common_tags" {
  description = "List of environment variables for the task"
  type        = map(string)
}

variable "instance_type" {
  description = "Instance type for cluster"
  type        = string
  default     = "t3.medium"
}

variable "vpc_id" {
  description = "VPC id for VPC of cluster"
  type        = string
}

variable "target_capacity_provider" {
  description = "Number from 1 to 100 corresponding to the capacity provider target"
  type        = number
}

variable "security_group_additional_cidr_blocks" {
  description = "CIDR range to allow ingress at security group"
  type        = list(string)
  default     = []
}
