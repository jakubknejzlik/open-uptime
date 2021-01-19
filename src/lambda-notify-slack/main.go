package main

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"time"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/hako/durafmt"
)

type Monitor struct {
	ID                string     `json:"id"`
	Name              string     `json:"name"`
	Status            string     `json:"status"`
	StatusDescription string     `json:"statusDescription"`
	PrevStatusDate    *time.Time `json:"prevStatusDate"`
}

func main() {
	if os.Getenv("AWS_LAMBDA_FUNCTION_NAME") == "" {
		fmt.Println("empty AWS_LAMBDA_FUNCTION_NAME", os.Getenv("AWS_LAMBDA_FUNCTION_NAME"))
		now := time.Now().Add(-5 * time.Minute)
		m := Monitor{
			ID:                "test",
			Name:              "test monitor",
			Status:            "UP",
			StatusDescription: "blah",
			PrevStatusDate:    &now,
		}
		mJson, _ := json.Marshal(m)
		err := handleRequest(context.Background(), events.CloudWatchEvent{Detail: mJson})
		if err != nil {
			panic(err)
		}
	} else {
		lambda.Start(handleRequest)
	}
}

func handleRequest(ctx context.Context, request events.CloudWatchEvent) (err error) {
	monitor := Monitor{}
	err = json.Unmarshal(request.Detail, &monitor)
	if err != nil {
		return
	}

	if monitor.Status == "UP" {
		duration := ""
		if monitor.PrevStatusDate != nil {
			diff := time.Now().Sub(*monitor.PrevStatusDate).Round(time.Second)
			duration = ". It was down for " + durafmt.Parse(diff).String()
		}
		err = SendSlackMessage(SendSlackMessageOptions{
			Text: fmt.Sprintf("Monitoring %s is %s%s", monitor.Name, monitor.Status, duration),
		})
	} else {
		err = SendSlackMessage(SendSlackMessageOptions{
			Text: fmt.Sprintf("Monitoring %s is %s, reason: %s", monitor.Name, monitor.Status, monitor.StatusDescription),
		})
	}
	return
}
