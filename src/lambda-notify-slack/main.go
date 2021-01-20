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

func main() {
	if os.Getenv("AWS_LAMBDA_FUNCTION_NAME") == "" {
		fmt.Println("empty AWS_LAMBDA_FUNCTION_NAME", os.Getenv("AWS_LAMBDA_FUNCTION_NAME"))
		now := time.Now().Add(-5 * time.Minute)
		m := StatusChange{
			Monitor: Monitor{
				ID:         "test",
				Name:       "test monitor",
				Status:     "DOWN",
				StatusDate: &now,
			},
			Result: Result{
				MonitorID:   "test",
				Events:      []ResultEvent{},
				Status:      "UP",
				Description: "testing slack notification",
				Time:        time.Now(),
			},
		}
		mJSON, _ := json.Marshal(m)
		err := handleRequest(context.Background(), events.CloudWatchEvent{Detail: mJSON})
		if err != nil {
			panic(err)
		}
	} else {
		lambda.Start(handleRequest)
	}
}

func handleRequest(ctx context.Context, request events.CloudWatchEvent) (err error) {
	change := StatusChange{}
	err = json.Unmarshal(request.Detail, &change)
	if err != nil {
		return
	}

	if change.Result.Status == "UP" {
		duration := ""
		if change.Monitor.StatusDate != nil {
			diff := time.Now().Sub(*change.Monitor.StatusDate).Round(time.Second)
			duration = ". It was down for " + durafmt.Parse(diff).String()
		}
		err = SendSlackMessage(SendSlackMessageOptions{
			Text: fmt.Sprintf("Monitor %s is %s%s", change.Monitor.Name, change.Result.Status, duration),
		})
	} else {
		err = SendSlackMessage(SendSlackMessageOptions{
			Text: fmt.Sprintf("Monitor %s is %s, reason: %s", change.Monitor.Name, change.Result.Status, change.Result.Description),
		})
	}
	return
}
