include .env
export


init:
	terraform init

plan:
	terraform plan

apply:	
	terraform apply

build-lambda-scheduler:
	cd src/lambda-scheduler && GOOS=linux GOARCH=amd64 go build -o ../../.tmp/lambda-scheduler *.go
build-lambda-http:
	cd src/lambda-http && GOOS=linux GOARCH=amd64 go build -o ../../.tmp/lambda-http *.go
build-lambda-results:
	cd src/lambda-results && GOOS=linux GOARCH=amd64 go build -o ../../.tmp/lambda-results *.go
build-lambda-alert:
	cd src/lambda-alert && GOOS=linux GOARCH=amd64 go build -o ../../.tmp/lambda-alert *.go
build-lambda-notify-slack:
	cd src/lambda-notify-slack && GOOS=linux GOARCH=amd64 go build -o ../../.tmp/lambda-notify-slack *.go

deploy: build-lambda-scheduler build-lambda-http build-lambda-results build-lambda-alert build-lambda-notify-slack init apply

run-lambda-scheduler:
	cd src/lambda-scheduler && go run main.go