locals {
  tags = {
    owner = "terraform"
    team  = "a-team"
    env   = "prod"
  }
}

variable "repo_bucket" {
  type        = string
  description = "The name of the bucket to be used as storage for yum repos"
}

variable "image_bucket" {
  type        = string
  description = "The name of the bucket to be usd as storage for images"
}

provider "aws" {
  profile = "default"
  region  = "eu-west-1"
}

resource "aws_s3_bucket" "auto-ci-pipeline-repos" {
  bucket = var.repo_bucket
  acl    = "public-read"
  tags   = local.tags
}

resource "aws_s3_bucket" "auto-ci-pipeline-images" {
  bucket = var.image_bucket
  acl    = "public-read"
  tags   = local.tags
}
