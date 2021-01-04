resource "aws_cloudformation_stack" "timestream" {
  name = "openuptime"

  parameters = {
    databaseName = "openuptime"
    tableName    = "monitors"
  }

  template_body = <<STACK
{
  "Parameters" : {
    "databaseName" : {
      "Type" : "String"
    },
    "tableName" : {
      "Type" : "String"
    }
  },
  "Resources" : {
    "database": {
      "Type" : "AWS::Timestream::Database",
      "Properties" : {
        "DatabaseName" : { "Ref" : "databaseName" },
        "Tags" : [
          {"Key": "app", "Value": "openupitime"}
        ]
      }
    },
    "table":{
        "Type" : "AWS::Timestream::Table", 
        "Properties" : {
            "DatabaseName" : { "Ref" : "databaseName" }, 
            "TableName" : { "Ref" : "tableName" }, 
            "RetentionProperties" : {
                "MemoryStoreRetentionPeriodInHours": "1",
                "MagneticStoreRetentionPeriodInDays": "30"
            },
            "Tags" : [
                {"Key": "app", "Value": "openupitime"}
            ]
        } 
    }
  },
  "Outputs" : {
    "TableARN" : {
        "Description" : "Timestream Table ARN",
        "Value" : { "Fn::GetAtt" : [ "table", "Arn" ] }
    }
  }
}
STACK
}
