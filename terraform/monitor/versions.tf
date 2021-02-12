terraform {
  required_providers {
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
