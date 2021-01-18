package main

import (
	"context"
	"encoding/json"
	"fmt"
	"os"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
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
		m := Monitor{
			ID:                "test",
			Name:              "test monitor",
			Status:            "UP",
			StatusDescription: "blah",
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
		err = SendSlackMessage(SendSlackMessageOptions{
			Text: fmt.Sprintf("Monitoring %s is %s", monitor.Name, monitor.Status),
		})
	} else {
		err = SendSlackMessage(SendSlackMessageOptions{
			Text: fmt.Sprintf("Monitoring %s is %s, reason: %s", monitor.Name, monitor.Status, monitor.StatusDescription),
		})
	}
	return
}
