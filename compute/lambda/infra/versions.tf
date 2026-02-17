terraform {
  required_providers {

    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.32"
    }
  }
}

provider "aws" {
  region  = "ca-central-1"
  profile = "default"
}
