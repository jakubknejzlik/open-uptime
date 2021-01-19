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

	"github.com/aws/aws-sdk-go/service/dynamodb"
	"github.com/aws/aws-sdk-go/service/dynamodb/dynamodbattribute"
	"github.com/aws/aws-sdk-go/service/timestreamwrite"
	"golang.org/x/net/http2"
)

type Monitor struct {
	ID       string      `json:"id"`
	Schedule string      `json:"schedule"`
	Config   interface{} `json:"config"`
	Status   string      `json:"status"`
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
	Time        time.Time     `json:"time"`
}

func main() {
	if os.Getenv("AWS_LAMBDA_FUNCTION_NAME") == "" {
		fmt.Println("empty AWS_LAMBDA_FUNCTION_NAME", os.Getenv("AWS_LAMBDA_FUNCTION_NAME"))
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
				Status:      "DOWN",
				Description: "Connection timeout",
				Time:        time.Now(),
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

	records := []*timestreamwrite.Record{}

	for _, message := range request.Records {
		results := []Result{}
		json.Unmarshal([]byte(message.Body), &results)

		err = updateMonitorStatus(ctx, sess, results)
		if err != nil {
			return
		}

		for _, result := range results {
			for _, event := range result.Events {
				rec := timestreamwrite.Record{
					Dimensions: []*timestreamwrite.Dimension{
						{Name: aws.String("monitorId"), Value: &result.MonitorID},
					},
					MeasureName:      aws.String(event.Name),
					MeasureValue:     aws.String(event.Value),
					MeasureValueType: aws.String(event.ValueType),
					Time:             aws.String(strconv.FormatInt(result.Time.UnixNano(), 10)),
					TimeUnit:         aws.String(timestreamwrite.TimeUnitNanoseconds),
				}
				records = append(records, &rec)
			}
		}
	}

	fmt.Println("records to send:", len(records))

	if len(records) > 0 {
		err = writeRecordsToTimeStream(ctx, sess, records)
	}

	return
}

func writeRecordsToTimeStream(ctx context.Context, sess *session.Session, records []*timestreamwrite.Record) (err error) {
	tsDatabaseName := os.Getenv("TIMESTREAM_DATABASE_NAME")
	tsTableName := os.Getenv("TIMESTREAM_TABLE_NAME")

	writeSvc := timestreamwrite.New(sess) //, aws.NewConfig().WithLogLevel(aws.LogDebugWithHTTPBody))

	input := &timestreamwrite.WriteRecordsInput{
		DatabaseName: aws.String(tsDatabaseName),
		TableName:    aws.String(tsTableName),
		Records:      records,
	}
	_, err = writeSvc.WriteRecordsWithContext(ctx, input)
	return
}

func updateMonitorStatus(ctx context.Context, sess *session.Session, results []Result) (err error) {
	ddbTableName := os.Getenv("DYNAMODB_MONITORS_TABLE_NAME")
	svc := dynamodb.New(session.New())

	if len(results) == 0 {
		return
	}

	fmt.Printf("updating %d statuses to %s\n", len(results), ddbTableName)

	monitorIDs := []string{}
	resultsByMonitorID := map[string]Result{}

	for _, result := range results {
		monitorIDs = append(monitorIDs, result.MonitorID)
		resultsByMonitorID[result.MonitorID] = result
	}

	monitors, err := getMonitorStatuses(ctx, sess, monitorIDs)
	if err != nil {
		return
	}

	for _, monitor := range monitors {
		result := resultsByMonitorID[monitor.ID]
		if monitor.Status == result.Status {
			continue
		}
		input := &dynamodb.UpdateItemInput{
			ExpressionAttributeNames: map[string]*string{
				"#S":     aws.String("status"),
				"#SDesc": aws.String("statusDescription"),
				"#SDate": aws.String("statusDate"),
			},
			ExpressionAttributeValues: map[string]*dynamodb.AttributeValue{
				":status": {
					S: aws.String(result.Status),
				},
				":statusDescription": {
					S: aws.String(result.Description),
				},
				":statusDate": {
					S: aws.String(result.Time.Format(time.RFC3339)),
				},
			},
			Key: map[string]*dynamodb.AttributeValue{
				"PK": {
					S: aws.String(result.MonitorID),
				},
				"SK": {
					S: aws.String("MONITOR"),
				},
			},
			TableName:        aws.String(ddbTableName),
			UpdateExpression: aws.String("SET #S = :status,#SDesc = :statusDescription,#SDate = :statusDate"),
		}

		_, err = svc.UpdateItemWithContext(ctx, input)
	}
	return
}

func getMonitorStatuses(ctx context.Context, sess *session.Session, monitorIDs []string) (monitors []Monitor, err error) {
	ddbTableName := os.Getenv("DYNAMODB_MONITORS_TABLE_NAME")
	svc := dynamodb.New(session.New())
	batchGetKeys := []map[string]*dynamodb.AttributeValue{}

	for _, monitorID := range monitorIDs {
		batchGetKeys = append(batchGetKeys, map[string]*dynamodb.AttributeValue{
			"PK": {
				S: aws.String(monitorID),
			},
			"SK": {
				S: aws.String("MONITOR"),
			},
		})
	}

	batchGetItems := map[string]*dynamodb.KeysAndAttributes{}
	batchGetItems[ddbTableName] = &dynamodb.KeysAndAttributes{
		Keys:                 batchGetKeys,
		ProjectionExpression: aws.String("id,#status"),
		ExpressionAttributeNames: aws.StringMap(map[string]string{
			"#status": "status",
		}),
	}
	getItemsInput := &dynamodb.BatchGetItemInput{
		RequestItems: batchGetItems,
	}

	items, err := svc.BatchGetItemWithContext(ctx, getItemsInput)
	if err != nil {
		return
	}
	monitors = []Monitor{}
	err = dynamodbattribute.UnmarshalListOfMaps(items.Responses[ddbTableName], &monitors)
	return
}
