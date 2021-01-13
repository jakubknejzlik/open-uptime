resource "aws_appsync_graphql_api" "test" {
  authentication_type = "API_KEY"
  name                = "openuptime"

  xray_enabled = true

  tags = {
    app = "openuptime"
  }

  schema = <<EOF
input MonitorCreateInput {
    id: ID
    name: String!
    schedule: String!
    config: AWSJSON!
    enabled: Boolean
}
input MonitorUpdateInput {
    name: String
    schedule: String
    config: AWSJSON
    enabled: Boolean
}

enum MonitorStatusResult {
    OK
    ERROR
}

type MonitorStatus {
    date: AWSDateTime!
    result: MonitorStatusResult!
    description: String
}

type Monitor {
    id: ID!
    name: String
    schedule: String!
    config: AWSJSON!
    version: Int
    enabled: Boolean!

    latestStatus: MonitorStatus
}

type Mutation {
    createMonitor(input: MonitorCreateInput!): Monitor!
    updateMonitor(id: ID!, input: MonitorUpdateInput!, expectedVersion: Int): Monitor
    deleteMonitor(id: ID!): Monitor
}

type Query {
    monitor(id: ID!): Monitor
}

schema {
    query: Query
    mutation: Mutation
}
EOF
}

resource "aws_appsync_datasource" "monitors" {
  api_id           = aws_appsync_graphql_api.test.id
  name             = "openuptime_monitors"
  service_role_arn = aws_iam_role.monitors.arn
  type             = "AMAZON_DYNAMODB"

  dynamodb_config {
    table_name = aws_dynamodb_table.monitors.name
  }
}

resource "aws_appsync_api_key" "test" {
  api_id = aws_appsync_graphql_api.test.id
}

resource "aws_appsync_resolver" "get-monitor" {
  api_id      = aws_appsync_graphql_api.test.id
  field       = "monitor"
  type        = "Query"
  data_source = aws_appsync_datasource.monitors.name

  request_template = <<EOF
{
    "version": "2017-02-28",
    "operation": "GetItem",
    "key": {
        "id": $util.dynamodb.toDynamoDBJson($ctx.args.id),
    }
}
EOF

  response_template = <<EOF
$util.toJson($ctx.result)
EOF

}

resource "aws_appsync_resolver" "create-monitor" {
  api_id      = aws_appsync_graphql_api.test.id
  field       = "createMonitor"
  type        = "Mutation"
  data_source = aws_appsync_datasource.monitors.name

  request_template = <<EOF
{
    "version" : "2017-02-28",
    "operation" : "PutItem",
    "key": {
        "id": $util.dynamodb.toDynamoDBJson($util.defaultIfNullOrEmpty($ctx.arguments.input.id,$util.autoId())),
    },
    "attributeValues" : {
        "name" : $util.dynamodb.toDynamoDBJson($ctx.arguments.input.name),
        "schedule" : $util.dynamodb.toDynamoDBJson($ctx.arguments.input.schedule),
        "config" : $util.dynamodb.toDynamoDBJson($ctx.arguments.input.config),
        "enabled" : $util.dynamodb.toDynamoDBJson($util.defaultIfNull($ctx.arguments.input.enabled,true)),
        "version" : { "N" : 1 }
    }
}
EOF

  response_template = <<EOF
$util.toJson($ctx.result)
EOF

}

resource "aws_appsync_resolver" "update-monitor" {
  api_id      = aws_appsync_graphql_api.test.id
  field       = "updateMonitor"
  type        = "Mutation"
  data_source = aws_appsync_datasource.monitors.name

  request_template = <<EOF
{
    "version" : "2017-02-28",
    "operation" : "UpdateItem",
    "key" : {
        "id" : $util.dynamodb.toDynamoDBJson($context.arguments.id)
    },

    ## Set up some space to keep track of things you're updating **
    #set( $expNames  = {} )
    #set( $expValues = {} )
    #set( $expSet = {} )
    #set( $expAdd = {} )
    #set( $expRemove = [] )

    ## Increment "version" by 1 **
    $!{expAdd.put("version", ":one")}
    $!{expValues.put(":one", { "N" : 1 })}

    #foreach( $entry in $context.arguments.input.entrySet() )
        #if( (!$entry.value) && ("$!{entry.value}" == "") )
            ## If the argument is set to "null", then remove that attribute from the item in DynamoDB **

            #set( $discard = $${expRemove.add("#$${entry.key}")} )
            $!{expNames.put("#$${entry.key}", "$entry.key")}
        #else
            ## Otherwise set (or update) the attribute on the item in DynamoDB **

            $!{expSet.put("#$${entry.key}", ":$${entry.key}")}
            $!{expNames.put("#$${entry.key}", "$entry.key")}
            $!{expValues.put(":$${entry.key}", $util.dynamodb.toDynamoDB($${entry.value}))}
        #end
    #end

    ## Start building the update expression, starting with attributes you're going to SET **
    #set( $expression = "" )
    #if( !$${expSet.isEmpty()} )
        #set( $expression = "SET" )
        #foreach( $entry in $expSet.entrySet() )
            #set( $expression = "$${expression} $${entry.key} = $${entry.value}" )
            #if ( $foreach.hasNext )
                #set( $expression = "$${expression}," )
            #end
        #end
    #end

    ## Continue building the update expression, adding attributes you're going to ADD **
    #if( !$${expAdd.isEmpty()} )
        #set( $expression = "$${expression} ADD" )
        #foreach( $entry in $expAdd.entrySet() )
            #set( $expression = "$${expression} $${entry.key} $${entry.value}" )
            #if ( $foreach.hasNext )
                #set( $expression = "$${expression}," )
            #end
        #end
    #end

    ## Continue building the update expression, adding attributes you're going to REMOVE **
    #if( !$${expRemove.isEmpty()} )
        #set( $expression = "$${expression} REMOVE" )

        #foreach( $entry in $expRemove )
            #set( $expression = "$${expression} $${entry}" )
            #if ( $foreach.hasNext )
                #set( $expression = "$${expression}," )
            #end
        #end
    #end

    ## Finally, write the update expression into the document, along with any expressionNames and expressionValues **
    "update" : {
        "expression" : "$${expression}"
        #if( !$${expNames.isEmpty()} )
            ,"expressionNames" : $utils.toJson($expNames)
        #end
        #if( !$${expValues.isEmpty()} )
            ,"expressionValues" : $utils.toJson($expValues)
        #end
    },

    #if( !$$util.isNullOrEmpty($$context.arguments.expectedVersion) )
    "condition" : {
        "expression"       : "version = :expectedVersion",
        "expressionValues" : {
            ":expectedVersion" : $util.dynamodb.toDynamoDBJson($context.arguments.expectedVersion)
        }
    }
    #end
}
EOF

  response_template = <<EOF
$util.toJson($ctx.result)
EOF

}

resource "aws_appsync_resolver" "delete-monitor" {
  api_id      = aws_appsync_graphql_api.test.id
  field       = "deleteMonitor"
  type        = "Mutation"
  data_source = aws_appsync_datasource.monitors.name

  request_template = <<EOF
{
    "version": "2017-02-28",
    "operation": "DeleteItem",
    "key": {
        "id": $util.dynamodb.toDynamoDBJson($ctx.args.id),
    }
}
EOF

  response_template = <<EOF
$util.toJson($ctx.result)
EOF

}
