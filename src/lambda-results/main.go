package main

import (
	"context"
	"encoding/json"
	"fmt"
	"net"
	"net/http"
	"os"
	"strconv"
	"time"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"

	"github.com/aws/aws-sdk-go/service/timestreamwrite"
	"golang.org/x/net/http2"
)

type Monitor struct {
	ID       string      `json:"id"`
	Schedule string      `json:"schedule"`
	Config   interface{} `json:"config"`
}

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
	Time        string        `json:"time"`
	TimeUnit    string        `json:"timeUnit"`
}

func main() {
	if os.Getenv("AWS_LAMBDA_FUNCTION_NAME") == "" {
		fmt.Println("empty AWS_LAMBDA_FUNCTION_NAME", os.Getenv("AWS_LAMBDA_FUNCTION_NAME"))
		time := strconv.FormatInt(time.Now().UnixNano(), 10)
		m := []Result{
			{
				MonitorID: "test",
				Events: []ResultEvent{
					{
						Name:      "duration",
						Value:     "123",
						ValueType: "DOUBLE",
					},
				},
				Status:      "OK",
				Description: "OK",
				Time:        time,
				TimeUnit:    "NANOSECONDS",
			},
		}
		data, _ := json.Marshal(m)
		message := events.SQSMessage{Body: string(data)}
		err := handleRequest(context.Background(), events.SQSEvent{Records: []events.SQSMessage{message}})
		if err != nil {
			panic(err)
		}
	} else {
		lambda.Start(handleRequest)
	}
}

func handleRequest(ctx context.Context, request events.SQSEvent) (err error) {
	records := []*timestreamwrite.Record{}

	for _, message := range request.Records {
		results := []Result{}
		json.Unmarshal([]byte(message.Body), &results)
		for _, result := range results {
			for _, event := range result.Events {
				rec := timestreamwrite.Record{
					Dimensions: []*timestreamwrite.Dimension{
						{Name: aws.String("monitorId"), Value: &result.MonitorID},
					},
					MeasureName:      aws.String(event.Name),
					MeasureValue:     aws.String(event.Value),
					MeasureValueType: aws.String(event.ValueType),
					Time:             &result.Time,
					TimeUnit:         aws.String(result.TimeUnit),
				}
				records = append(records, &rec)
			}
		}
	}

	fmt.Println("records to send:", len(records))

	if len(records) > 0 {

		tsDatabaseName := os.Getenv("TIMESTREAM_DATABASE_NAME")
		tsTableName := os.Getenv("TIMESTREAM_TABLE_NAME")

		tr := &http.Transport{
			ResponseHeaderTimeout: 20 * time.Second,
			// Using DefaultTransport values for other parameters: https://golang.org/pkg/net/http/#RoundTripper
			Proxy: http.ProxyFromEnvironment,
			DialContext: (&net.Dialer{
				KeepAlive: 30 * time.Second,
				DualStack: true,
				Timeout:   30 * time.Second,
			}).DialContext,
			MaxIdleConns:          100,
			IdleConnTimeout:       90 * time.Second,
			TLSHandshakeTimeout:   10 * time.Second,
			ExpectContinueTimeout: 1 * time.Second,
		}

		// So client makes HTTP/2 requests
		http2.ConfigureTransport(tr)

		sess := session.Must(session.NewSession(&aws.Config{MaxRetries: aws.Int(3), HTTPClient: &http.Client{Transport: tr}}))
		writeSvc := timestreamwrite.New(sess) //, aws.NewConfig().WithLogLevel(aws.LogDebugWithHTTPBody))

		input := &timestreamwrite.WriteRecordsInput{
			DatabaseName: aws.String(tsDatabaseName),
			TableName:    aws.String(tsTableName),
			Records:      records,
		}
		_, err = writeSvc.WriteRecordsWithContext(ctx, input)
	}
	return
}
