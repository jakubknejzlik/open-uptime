variable "name" {

}
variable "schedule" {

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
  }

  compute_from_create = true
  compute_mutation_keys = {
    "id" = "monitor.id"
  }

  create_mutation = <<EOF
mutation CreateMonitor($name: String!, $config: AWSJSON!, $schedule: String!) {
  monitor: createMonitor(input: {name:$name, config:$config, schedule: $schedule}) {
    id
  }
}
  EOF
  update_mutation = <<EOF
mutation UpdateMonitor($id: ID!,$name: String!, $config: AWSJSON!, $schedule: String!) {
  monitor: updateMonitor(id: $id, input: {name:$name, config:$config, schedule: $schedule}) {
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
