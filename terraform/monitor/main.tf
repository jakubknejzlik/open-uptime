variable "name" {

}
variable "schedule" {

}
variable "type" {
  default = "HTTP"
}
variable "config" {
  type = object({
    url = string
  })
}

resource "graphql_mutation" "monitor" {
  mutation_variables = {
    name     = var.name
    config   = jsonencode(var.config)
    schedule = var.schedule
    type     = var.type
  }

  compute_from_create = true
  compute_mutation_keys = {
    "id" = "monitor.id"
  }

  create_mutation = <<EOF
mutation CreateMonitor($name: String!, $config: AWSJSON!, $schedule: String!, $type: MonitorType!) {
  monitor: createMonitor(input: {name:$name, config:$config, schedule: $schedule, type: $type}) {
    id
  }
}
  EOF
  update_mutation = <<EOF
mutation UpdateMonitor($id: ID!,$name: String!, $config: AWSJSON!, $schedule: String!, $type: MonitorType!) {
  monitor: updateMonitor(id: $id, input: {name:$name, config:$config, schedule: $schedule, type: $type}) {
    id
  }
}
  EOF
  delete_mutation = <<EOF
mutation DeleteMonitor($id: ID!) {
  monitor: deleteMonitor(id: $id) {
    id
  }
}
  EOF
  read_query      = <<EOF
query Monitor($id: ID!) {
  monitor(id: $id) {
    id
  }
}
  EOF
}
