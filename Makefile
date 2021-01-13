include .env
export


init:
	terraform init

plan: init
	terraform plan

apply: init	
	terraform apply

build-lambda-scheduler:
	cd src/lambda-scheduler && GOOS=linux GOARCH=amd64 go build -o ../../.tmp/lambda-scheduler main.go
build-lambda-http:
	cd src/lambda-http && GOOS=linux GOARCH=amd64 go build -o ../../.tmp/lambda-http main.go
build-lambda-results:
	cd src/lambda-results && GOOS=linux GOARCH=amd64 go build -o ../../.tmp/lambda-results main.go

deploy: build-lambda-scheduler build-lambda-http build-lambda-results apply

run-lambda-scheduler:
	cd src/lambda-scheduler && go run main.go