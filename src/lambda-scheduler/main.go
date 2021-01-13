package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"time"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/sqs"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/dynamodb"
	"github.com/aws/aws-sdk-go/service/dynamodb/dynamodbattribute"
	cron "github.com/robfig/cron/v3"
)

type Monitor struct {
	ID       string      `json:"id"`
	Schedule string      `json:"schedule"`
	Config   interface{} `json:"config"`
	Enabled  bool        `json:"enabled"`
}

func handleRequest(ctx context.Context, request events.CloudWatchEvent) (err error) {
	tableName := os.Getenv("DYNAMODB_TABLE_NAME")
	queueURL := os.Getenv("SQS_QUEUE_URL")

	specParser := cron.NewParser(cron.Minute | cron.Hour | cron.Dom | cron.Month | cron.Dow)

	cfg, err := config.LoadDefaultConfig(ctx)
	if err != nil {
		log.Fatalf("unable to load SDK config, %v", err)
	}
	sess := session.Must(session.NewSessionWithOptions(session.Options{}))

	// dynDB := dynamodb.NewFromConfig(cfg)
	dynDB := dynamodb.New(sess)
	sqsSvc := sqs.NewFromConfig(cfg)

	resp, err := dynDB.ScanWithContext(ctx, &dynamodb.ScanInput{
		TableName: aws.String(tableName),
	})

	if err != nil {
		// log.Fatalf("failed to query items, %v", err)
		return
	}

	fmt.Printf("items: %d, scans: %d, capacity: %v\n", *resp.Count, *resp.ScannedCount, resp.ConsumedCapacity)
	monitors := []Monitor{}
	err = dynamodbattribute.UnmarshalListOfMaps(resp.Items, &monitors)
	if err != nil {
		return
	}

	for _, monitor := range monitors {
		if !monitor.Enabled {
			continue
		}

		schedule, parseErr := specParser.Parse(monitor.Schedule)
		if parseErr != nil {
			err = fmt.Errorf("Could not parse %s, with error %v", monitor.Schedule, parseErr)
			return
		}
		now := time.Now()
		next := schedule.Next(now)
		secs := next.Sub(now).Seconds()

		if secs < 60 {
			data, jsonErr := json.Marshal(monitor)
			if jsonErr != nil {
				err = jsonErr
				return
			}

			sqsResp, sqsErr := sqsSvc.SendMessage(ctx, &sqs.SendMessageInput{
				MessageBody: aws.String(string(data)),
				QueueUrl:    &queueURL,
			})
			if sqsErr != nil {
				err = sqsErr
				return
			}

			fmt.Println("message sent: ", aws.ToString(sqsResp.MessageId))
		}
	}

	return
}

func main() {
	if os.Getenv("AWS_LAMBDA_FUNCTION_NAME") == "" {
		fmt.Println("empty AWS_LAMBDA_FUNCTION_NAME", os.Getenv("AWS_LAMBDA_FUNCTION_NAME"))
		err := handleRequest(context.Background(), events.CloudWatchEvent{})
		if err != nil {
			panic(err)
		}
	} else {
		lambda.Start(handleRequest)
	}
}
