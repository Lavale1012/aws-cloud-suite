variable "vpc_id" {
  description = "var for vpc id"
  type = string
}
variable "private_subnet_id_1" {
  description = "ID of the first private subnet"
  type = string

}

variable "private_subnet_id_2" {
  description = "ID of the second private subnet"
  type = string

}

variable "project_name" {
  description = "Name of the project"
  type = string
}