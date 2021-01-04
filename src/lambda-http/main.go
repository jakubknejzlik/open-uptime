package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
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
	ID       string
	Schedule string
	Config   string
}

type Config struct {
	URL string
}

func handleRequest(ctx context.Context, request events.SQSEvent) (err error) {
	for _, message := range request.Records {
		err = handleMessage(ctx, message)
	}
	return
}
func handleMessage(ctx context.Context, message events.SQSMessage) (err error) {
	tsDatabaseName := os.Getenv("TIMESTREAM_DATABASE_NAME")
	tsTableName := os.Getenv("TIMESTREAM_TABLE_NAME")

	monitor := Monitor{}
	err = json.Unmarshal([]byte(message.Body), &monitor)
	if err != nil {
		return
	}

	monitorConfig := Config{}
	err = json.Unmarshal([]byte(monitor.Config), &monitorConfig)
	if err != nil {
		return
	}

	tp := newTransport()
	client := &http.Client{Transport: tp}

	resp, err := client.Get(monitorConfig.URL)
	if err != nil {
		return
	}
	defer resp.Body.Close()

	log.Println("Duration:", tp.Duration())
	log.Println("Request duration:", tp.ReqDuration())
	log.Println("Connection duration:", tp.ConnDuration())

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

	// cfg, err := config.LoadDefaultConfig(ctx, config.WithClientLogMode(aws.LogRequestWithBody))
	// if err != nil {
	// 	log.Fatalf("unable to load SDK config, %v", err)
	// }

	sess := session.Must(session.NewSession(&aws.Config{MaxRetries: aws.Int(3), HTTPClient: &http.Client{Transport: tr}}))
	writeSvc := timestreamwrite.New(sess) //, aws.NewConfig().WithLogLevel(aws.LogDebugWithHTTPBody))

	// fmt.Println("??", cfg.Region)
	// ts := timestreamwrite.NewFromConfig(cfg)
	// tsResponse, err := ts.WriteRecords(ctx, )
	time := aws.String(strconv.FormatInt(time.Now().UnixNano(), 10))
	records := &timestreamwrite.WriteRecordsInput{
		DatabaseName: aws.String(tsDatabaseName),
		TableName:    aws.String(tsTableName),
		Records: []*timestreamwrite.Record{
			{
				Dimensions: []*timestreamwrite.Dimension{
					{Name: aws.String("monitorId"), Value: &monitor.ID},
				},
				MeasureName:      aws.String("duration"),
				MeasureValue:     aws.String(fmt.Sprintf("%0.3f", float64(tp.Duration().Microseconds())/1000.0)),
				MeasureValueType: aws.String(timestreamwrite.MeasureValueTypeDouble),
				Time:             time,
				TimeUnit:         aws.String(timestreamwrite.TimeUnitNanoseconds),
			},
			{
				Dimensions: []*timestreamwrite.Dimension{
					{Name: aws.String("monitorId"), Value: &monitor.ID},
				},
				MeasureName:      aws.String("req_duration"),
				MeasureValue:     aws.String(fmt.Sprintf("%0.3f", float64(tp.ReqDuration().Microseconds())/1000.0)),
				MeasureValueType: aws.String(timestreamwrite.MeasureValueTypeDouble),
				Time:             time,
				TimeUnit:         aws.String(timestreamwrite.TimeUnitNanoseconds),
			},
			{
				Dimensions: []*timestreamwrite.Dimension{
					{Name: aws.String("monitorId"), Value: &monitor.ID},
				},
				MeasureName:      aws.String("conn_duration"),
				MeasureValue:     aws.String(fmt.Sprintf("%0.3f", float64(tp.ConnDuration().Microseconds())/1000.0)),
				MeasureValueType: aws.String(timestreamwrite.MeasureValueTypeDouble),
				Time:             time,
				TimeUnit:         aws.String(timestreamwrite.TimeUnitNanoseconds),
			},
			{
				Dimensions: []*timestreamwrite.Dimension{
					{Name: aws.String("monitorId"), Value: &monitor.ID},
				},
				MeasureName:      aws.String("http_status_code"),
				MeasureValue:     aws.String(fmt.Sprintf("%d", resp.StatusCode)),
				MeasureValueType: aws.String(timestreamwrite.MeasureValueTypeBigint),
				Time:             time,
				TimeUnit:         aws.String(timestreamwrite.TimeUnitNanoseconds),
			},
		},
	}
	tsResponse, err := writeSvc.WriteRecordsWithContext(ctx, records)
	fmt.Println("??", tsResponse, err)
	return
}

func main() {
	if os.Getenv("AWS_LAMBDA_FUNCTION_NAME") == "" {
		fmt.Println("empty AWS_LAMBDA_FUNCTION_NAME", os.Getenv("AWS_LAMBDA_FUNCTION_NAME"))
		m := Monitor{
			ID:       "test",
			Schedule: "* * * * *",
			Config:   "{\"url\":\"https://gimmedata.cz\"}",
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

type customTransport struct {
	rtp       http.RoundTripper
	dialer    *net.Dialer
	connStart time.Time
	connEnd   time.Time
	reqStart  time.Time
	reqEnd    time.Time
}

func newTransport() *customTransport {

	tr := &customTransport{
		dialer: &net.Dialer{
			Timeout:   30 * time.Second,
			KeepAlive: 30 * time.Second,
		},
	}
	tr.rtp = &http.Transport{
		Proxy:               http.ProxyFromEnvironment,
		Dial:                tr.dial,
		TLSHandshakeTimeout: 10 * time.Second,
	}
	return tr
}

func (tr *customTransport) RoundTrip(r *http.Request) (*http.Response, error) {
	tr.reqStart = time.Now()
	resp, err := tr.rtp.RoundTrip(r)
	tr.reqEnd = time.Now()
	return resp, err
}

func (tr *customTransport) dial(network, addr string) (net.Conn, error) {
	tr.connStart = time.Now()
	cn, err := tr.dialer.Dial(network, addr)
	tr.connEnd = time.Now()
	return cn, err
}

func (tr *customTransport) ReqDuration() time.Duration {
	return tr.Duration() - tr.ConnDuration()
}

func (tr *customTransport) ConnDuration() time.Duration {
	return tr.connEnd.Sub(tr.connStart)
}

func (tr *customTransport) Duration() time.Duration {
	return tr.reqEnd.Sub(tr.reqStart)
}
