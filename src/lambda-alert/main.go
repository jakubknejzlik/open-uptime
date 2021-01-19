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

type Monitor struct {
	ID                string     `json:"id"`
	Name              string     `json:"name"`
	Status            string     `json:"status"`
	StatusDescription string     `json:"statusDescription"`
	PrevStatusDate    *time.Time `json:"prevStatusDate"`
}

type MonitorEvent struct {
	PK          string    `json:"PK"`
	SK          string    `json:"SK"`
	MonitorID   string    `json:"monitorId"`
	Status      string    `json:"status"`
	Description string    `json:"description"`
	Date        time.Time `json:"date"`
}

func main() {
	if os.Getenv("AWS_LAMBDA_FUNCTION_NAME") == "" {
		fmt.Println("empty AWS_LAMBDA_FUNCTION_NAME", os.Getenv("AWS_LAMBDA_FUNCTION_NAME"))
		err := handleRequest(context.Background(), events.DynamoDBEvent{Records: []events.DynamoDBEventRecord{
			{
				EventName: string(events.DynamoDBOperationTypeModify),
				Change: events.DynamoDBStreamRecord{
					OldImage: map[string]events.DynamoDBAttributeValue{
						"status":     events.NewStringAttribute("UP"),
						"statusDate": events.NewStringAttribute(time.Now().Format(time.RFC3339Nano)),
					},
					NewImage: map[string]events.DynamoDBAttributeValue{
						"status":            events.NewStringAttribute("DOWN"),
						"id":                events.NewStringAttribute("test"),
						"name":              events.NewStringAttribute("test"),
						"statusDescription": events.NewStringAttribute("something bad happened"),
					},
				},
			},
		}})
		if err != nil {
			panic(err)
		}
	} else {
		lambda.Start(handleRequest)
	}
}

func handleRequest(ctx context.Context, request events.DynamoDBEvent) (err error) {

	sess, err := session.NewSession(&aws.Config{})
	if err != nil {
		return
	}

	monitors := []Monitor{}

	for _, record := range request.Records {
		if record.EventName == string(events.DynamoDBOperationTypeModify) {
			oldStatus := record.Change.OldImage["status"].String()
			_, oldDateSet := record.Change.OldImage["statusDate"]
			oldStatusDate := record.Change.OldImage["statusDate"].String()
			newStatus := record.Change.NewImage["status"].String()
			if oldStatus == newStatus {
				continue
			}

			ID := record.Change.NewImage["id"].String()
			name := record.Change.NewImage["name"].String()
			statusDescription := record.Change.NewImage["statusDescription"].String()
			var statusDate *time.Time
			if oldDateSet {
				_statusDate, _err := time.Parse(time.RFC3339Nano, oldStatusDate)
				if _err != nil {
					err = _err
					return
				}
				statusDate = &_statusDate
			}
			fmt.Println(oldStatus, "=>", newStatus, statusDate)

			monitor := Monitor{
				ID:                ID,
				Name:              name,
				Status:            newStatus,
				StatusDescription: statusDescription,
				PrevStatusDate:    statusDate,
			}
			monitors = append(monitors, monitor)
		}
	}

	if len(monitors) > 0 {
		err = writeEventBridgeEvent(ctx, sess, monitors)
		if err != nil {
			return
		}
		err = writeDynamoDBAlert(ctx, sess, monitors)
		if err != nil {
			return
		}
	}

	return
}

func writeEventBridgeEvent(ctx context.Context, sess *session.Session, monitors []Monitor) (err error) {
	eventBusName := os.Getenv("EVENTBRIDGE_BUS_NAME")
	client := eventbridge.New(sess)

	for _, monitor := range monitors {
		jsonMonitor, _err := json.Marshal(monitor)
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

func writeDynamoDBAlert(ctx context.Context, sess *session.Session, monitors []Monitor) (err error) {
	ddbTableName := os.Getenv("DYNAMODB_ALERTS_TABLE_NAME")
	svc := dynamodb.New(session.New())

	now := time.Now()

	for _, monitor := range monitors {
		event := MonitorEvent{
			PK:          monitor.ID,
			SK:          fmt.Sprintf("ALERT#%s", now.Format(time.RFC3339)),
			MonitorID:   monitor.ID,
			Status:      monitor.Status,
			Description: monitor.StatusDescription,
			Date:        now,
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
