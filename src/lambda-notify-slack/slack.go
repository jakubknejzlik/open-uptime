package main

import (
	"os"

	"github.com/ashwanthkumar/slack-go-webhook"
)

type SendSlackMessageOptions struct {
	Text      string
	Username  string
	Channel   string
	IconEmoji string
}

func SendSlackMessage(opts SendSlackMessageOptions) error {
	channel := os.Getenv("SLACK_CHANNEL")
	webhookURL := os.Getenv("SLACK_URL")
	payload := slack.Payload{
		Text:      opts.Text,
		Username:  getEnvStringWithDefault(opts.Username, "OpenUptime bot"),
		Channel:   "#" + getEnvStringWithDefault(opts.Channel, channel),
		IconEmoji: getEnvStringWithDefault(opts.IconEmoji, ":robot_face:"),
	}
	errors := slack.Send(webhookURL, "", payload)
	if len(errors) > 0 {
		return errors[0]
	}
	return nil
}

func getEnvStringWithDefault(str, def string) string {
	if str == "" {
		return def
	}
	return str
}
