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
	"github.com/aws/aws-sdk-go/service/eventbridge"
)

type Monitor struct {
	ID                string `json:"id"`
	Name              string `json:"name"`
	Status            string `json:"status"`
	StatusDescription string `json:"statusDescription"`
}

func main() {
	if os.Getenv("AWS_LAMBDA_FUNCTION_NAME") == "" {
		fmt.Println("empty AWS_LAMBDA_FUNCTION_NAME", os.Getenv("AWS_LAMBDA_FUNCTION_NAME"))
		err := handleRequest(context.Background(), events.DynamoDBEvent{Records: []events.DynamoDBEventRecord{
			{
				EventName: string(events.DynamoDBOperationTypeModify),
				Change: events.DynamoDBStreamRecord{
					OldImage: map[string]events.DynamoDBAttributeValue{
						"status": events.NewStringAttribute("OK"),
					},
					NewImage: map[string]events.DynamoDBAttributeValue{
						"status":            events.NewStringAttribute("ERROR"),
						"id":                events.NewStringAttribute("test"),
						"name":              events.NewStringAttribute("test monitor"),
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
	eventBusName := os.Getenv("EVENTBRIDGE_BUS_NAME")

	sess, err := session.NewSession(&aws.Config{})
	if err != nil {
		return
	}
	client := eventbridge.New(sess)

	for _, record := range request.Records {
		if record.EventName == string(events.DynamoDBOperationTypeModify) {
			oldStatus := record.Change.OldImage["status"].String()
			newStatus := record.Change.NewImage["status"].String()
			ID := record.Change.NewImage["id"].String()
			name := record.Change.NewImage["name"].String()
			statusDescription := record.Change.NewImage["statusDescription"].String()
			fmt.Println(oldStatus, "=>", newStatus)

			monitor := Monitor{
				ID:                ID,
				Name:              name,
				Status:            newStatus,
				StatusDescription: statusDescription,
			}

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
	}

	return
}
