variable "env_name" {
  description = "sandbox, dev, or prod environment"
  type        = string
  validation {
    condition     = contains(["sandbox", "dev", "qa", "stg", "prod"], var.env_name)
    error_message = "Allowed values for input_parameter are \"dev\", \"qa\", \"stg\", \"sandbox\" or \"prod\"."
  }
}

variable "service_name" {
  description = "Name of the service to be created"
  type        = string
}

variable "container_cpu" {
  description = "The number of cpu units reserved for the container"
  type        = number
  default     = "512"
}

variable "container_memory" {
  description = "The amount of memory reserved for the container"
  type        = number
  default     = "1024"
}

variable "container_image" {
  description = "The container image that will be launched"
  type        = string
}

variable "environment_variables" {
  description = "List of environment variables for the task"
  type        = list(map(string))
  default     = [{}]
}

variable "path_healthcheck" {
  description = "The path of the container healthcheck"
  type        = string
  default     = "/"
}

variable "service_cluster" {
  description = "Name of cluster where the service will be deployed"
  type        = string
}

variable "service_desired_count" {
  description = "Number of task inside the service"
  type        = number
  default     = 2
}

variable "vpc_id" {
  description = "VPC ID where the services are created"
  type        = string
}

variable "listener_arn" {
  description = "ARN of the listener to add the rule"
  type        = string
}

variable "https_listener_rules" {
  description = "A list of maps describing the Listener Rules for this ALB. Required key/values: actions, conditions. Optional key/values: priority, http_tcp_listener_index (default to http_tcp_listeners[count.index])"
  type        = any
  default     = []
}

variable "portMappings" {
  description = "The list of port mappings for the container"
  type        = list(any)
  default = [
    {
      containerPort = 8082
      protocol      = "tcp"
    },
    {
      containerPort = 8081
      protocol      = "tcp"
    }
  ]
}

variable "common_tags" {
  description = "List of environment variables for the task"
  type        = map(string)
}
