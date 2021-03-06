terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "3.22.0"
    }
    oauth = {
      source  = "SvenHamers/oauth"
      version = "0.2.3"
    }
    graphql = {
      source  = "sullivtr/graphql"
      version = "1.4.5"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "eu-west-1"
}
