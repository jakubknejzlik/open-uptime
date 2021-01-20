package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net"
	"net/http"
	"os"
	"sync"
	"time"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"

	"github.com/aws/aws-sdk-go/service/sns"
	"github.com/aws/aws-sdk-go/service/timestreamwrite"
	"github.com/mitchellh/mapstructure"
)

type Monitor struct {
	ID       string      `json:"id"`
	Schedule string      `json:"schedule"`
	Config   interface{} `json:"config"`
}

type MonitorConfig struct {
	URL string
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
		urls := []string{"https://novacloud.cz/", "https://gimmedata.cz/"}
		messages := []events.SQSMessage{}
		for i, url := range urls {
			m := Monitor{
				ID:       fmt.Sprintf("test%d", i),
				Schedule: "* * * * *",
				Config: map[string]string{
					"url": url,
				},
			}
			data, _ := json.Marshal(m)
			message := events.SQSMessage{Body: string(data)}
			messages = append(messages, message)
		}
		err := handleRequest(context.Background(), events.SQSEvent{Records: messages})
		if err != nil {
			panic(err)
		}
	} else {
		lambda.Start(handleRequest)
	}
}

func handleRequest(ctx context.Context, request events.SQSEvent) (err error) {
	results := []Result{}

	var wg sync.WaitGroup

	for _, message := range request.Records {
		wg.Add(1)
		go func(m events.SQSMessage) {
			defer wg.Done()
			res, _err := getRecordsForMessage(ctx, m)
			if _err != nil {
				err = _err
				return
			}
			results = append(results, res)
		}(message)
	}
	wg.Wait()

	fmt.Println("results to send:", len(results))

	if len(results) > 0 {
		jsonPayload, _err := json.Marshal(results)
		if _err != nil {
			err = _err
			return
		}
		snsARN := os.Getenv("SNS_ARN")
		sess := session.Must(session.NewSession(&aws.Config{}))

		client := sns.New(sess)
		input := &sns.PublishInput{
			Message:  aws.String(string(jsonPayload)),
			TopicArn: aws.String(snsARN),
		}

		_, err = client.PublishWithContext(ctx, input)
	}
	return
}
func getRecordsForMessage(ctx context.Context, message events.SQSMessage) (result Result, err error) {
	monitor := Monitor{}
	err = json.Unmarshal([]byte(message.Body), &monitor)
	if err != nil {
		return
	}

	recs, err := getEventsForMonitor(ctx, monitor)
	now := time.Now()
	if err != nil {
		result = Result{
			MonitorID:   monitor.ID,
			Events:      recs,
			Status:      "DOWN",
			Description: err.Error(),
			Time:        now,
		}
	} else {
		result = Result{
			MonitorID:   monitor.ID,
			Events:      recs,
			Status:      "UP",
			Description: "",
			Time:        now,
		}
	}
	err = nil

	return
}

func getEventsForMonitor(ctx context.Context, monitor Monitor) (res []ResultEvent, err error) {
	monitorConfig := MonitorConfig{}
	mapstructure.Decode(monitor.Config, &monitorConfig)
	if err != nil {
		return
	}

	tp := newTransport()
	client := &http.Client{Transport: tp}

	resp, err := client.Get(monitorConfig.URL)
	log.Println("Duration:", tp.Duration(), resp, err)
	if err != nil {
		return
	}
	defer resp.Body.Close()

	log.Println("Status:", resp.StatusCode, monitorConfig.URL)
	log.Println("Duration:", tp.Duration())
	log.Println("Request duration:", tp.ReqDuration())
	log.Println("Connection duration:", tp.ConnDuration())

	res = []ResultEvent{
		{
			Name:      "duration",
			Value:     fmt.Sprintf("%0.3f", float64(tp.Duration().Microseconds())/1000.0),
			ValueType: timestreamwrite.MeasureValueTypeDouble,
		},
		{
			Name:      "req_duration",
			Value:     fmt.Sprintf("%0.3f", float64(tp.ReqDuration().Microseconds())/1000.0),
			ValueType: timestreamwrite.MeasureValueTypeDouble,
		},
		{
			Name:      "conn_duration",
			Value:     fmt.Sprintf("%0.3f", float64(tp.ConnDuration().Microseconds())/1000.0),
			ValueType: timestreamwrite.MeasureValueTypeDouble,
		},
		{
			Name:      "http_status_code",
			Value:     fmt.Sprintf("%d", resp.StatusCode),
			ValueType: timestreamwrite.MeasureValueTypeBigint,
		},
	}

	if resp.StatusCode < 200 || resp.StatusCode >= 400 {
		err = fmt.Errorf("Unexpected status code %d from URL %s", resp.StatusCode, monitorConfig.URL)
	}

	return
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
			Timeout:   5 * time.Second,
			KeepAlive: 5 * time.Second,
		},
	}
	tr.rtp = &http.Transport{
		Proxy:               http.ProxyFromEnvironment,
		Dial:                tr.dial,
		TLSHandshakeTimeout: 3 * time.Second,
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
