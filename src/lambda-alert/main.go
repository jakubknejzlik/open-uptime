package main

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"time"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/dynamodb"
	"github.com/aws/aws-sdk-go/service/dynamodb/dynamodbattribute"
	"github.com/aws/aws-sdk-go/service/eventbridge"
)

type ResultEvent struct {
	Name      string `json:"name"`
	Value     string `json:"value"`
	ValueType string `json:"valueType"`
}
type Result struct {
	MonitorID   string        `json:"monitorId"`
	Events      []ResultEvent `json:"events"`
	Status      string        `json:"status"`
	Description string        `json:"description"`
	Time        time.Time     `json:"time"`
}
type StatusChange struct {
	Monitor Monitor
	Result  Result
}

type Monitor struct {
	ID         string     `json:"id"`
	Name       string     `json:"name"`
	Status     string     `json:"status"`
	StatusDate *time.Time `json:"statusDate"`
}

type MonitorAlert struct {
	PK             string     `json:"PK"`
	SK             string     `json:"SK"`
	MonitorID      string     `json:"monitorId"`
	EntityType     string     `json:"entityType"`
	Status         string     `json:"status"`
	Description    string     `json:"description"`
	Date           time.Time  `json:"date"`
	PrevStatusDate *time.Time `json:"prevStatusDate"`
}

func main() {
	if os.Getenv("AWS_LAMBDA_FUNCTION_NAME") == "" {
		fmt.Println("empty AWS_LAMBDA_FUNCTION_NAME", os.Getenv("AWS_LAMBDA_FUNCTION_NAME"))
		now := time.Now()
		statusChange := StatusChange{
			Monitor: Monitor{
				ID:         "local-test",
				Name:       "test",
				Status:     "UP",
				StatusDate: &now,
			},
			Result: Result{
				MonitorID:   "test",
				Events:      []ResultEvent{},
				Status:      "DOWN",
				Description: "testing",
				Time:        now,
			},
		}
		message, _ := json.Marshal(statusChange)
		request := events.SNSEvent{
			Records: []events.SNSEventRecord{
				{
					SNS: events.SNSEntity{
						Message: string(message),
					},
				},
			},
		}
		err := handleRequest(context.Background(), request)
		if err != nil {
			panic(err)
		}
	} else {
		lambda.Start(handleRequest)
	}
}

func handleRequest(ctx context.Context, request events.SNSEvent) (err error) {

	sess, err := session.NewSession(&aws.Config{})
	if err != nil {
		return
	}

	changesToNotify := []StatusChange{}

	for _, record := range request.Records {
		statusChange := StatusChange{}
		json.Unmarshal([]byte(record.SNS.Message), &statusChange)
		changesToNotify = append(changesToNotify, statusChange)
	}

	if len(changesToNotify) > 0 {
		err = writeEventBridgeEvent(ctx, sess, changesToNotify)
		if err != nil {
			return
		}
		err = writeDynamoDBAlert(ctx, sess, changesToNotify)
		if err != nil {
			return
		}
	}

	return
}

func writeEventBridgeEvent(ctx context.Context, sess *session.Session, changes []StatusChange) (err error) {
	eventBusName := os.Getenv("EVENTBRIDGE_BUS_NAME")
	client := eventbridge.New(sess)

	for _, change := range changes {
		jsonMonitor, _err := json.Marshal(change)
		if _err != nil {
			err = _err
			return
		}

		input := &eventbridge.PutEventsInput{
			Entries: []*eventbridge.PutEventsRequestEntry{
				{
					EventBusName: aws.String(eventBusName),
					Detail:       aws.String(string(jsonMonitor)),
					DetailType:   aws.String("OpenUptime Monitor Alert"),
					Source:       aws.String("https://openuptime-alert"),
					Time:         aws.Time(time.Now()),
				},
			},
		}
		_, err = client.PutEventsWithContext(ctx, input)
		if err != nil {
			return
		}
	}
	return
}

func writeDynamoDBAlert(ctx context.Context, sess *session.Session, changes []StatusChange) (err error) {
	ddbTableName := os.Getenv("DYNAMODB_ALERTS_TABLE_NAME")
	svc := dynamodb.New(session.New())

	now := time.Now()

	for _, change := range changes {
		event := MonitorAlert{
			PK:             "m#" + change.Monitor.ID,
			SK:             "a#" + now.Format(time.RFC3339),
			MonitorID:      "m#" + change.Monitor.ID,
			Status:         change.Result.Status,
			Description:    change.Result.Description,
			EntityType:     "MonitorAlert",
			PrevStatusDate: change.Monitor.StatusDate,
			Date:           change.Result.Time,
		}
		av, _err := dynamodbattribute.MarshalMap(event)
		if _err != nil {
			err = _err
			return
		}
		_, err = svc.PutItem(&dynamodb.PutItemInput{
			TableName: aws.String(ddbTableName),
			Item:      av,
		})
	}
	return
}
