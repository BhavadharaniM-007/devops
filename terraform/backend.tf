terraform {
  backend "s3" {
    bucket = "tfbhava-2002"
    key    = "terraform.tfstate"
    region = "us-east-1"
  }
}