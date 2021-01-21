module github.com/jakubknejzlik/open-uptime/lambda-scheduler

go 1.13

require (
	github.com/aws/aws-lambda-go v1.22.0
	github.com/aws/aws-sdk-go v1.36.19
	github.com/aws/aws-sdk-go-v2 v0.31.0
	github.com/aws/aws-sdk-go-v2/config v0.4.0
	github.com/aws/aws-sdk-go-v2/service/dynamodb v0.31.0 // indirect
	github.com/aws/aws-sdk-go-v2/service/sqs v0.31.0
	github.com/aws/aws-xray-sdk-go v1.2.0 // indirect
	github.com/robfig/cron/v3 v3.0.1
)
