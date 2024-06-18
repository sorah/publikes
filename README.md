# Publikes

Publish your Twitter likes in a cheap serverless manner. Uses AWS Lambda and Amazon S3 for collection and storage.

- Example: https://like.sorah.jp

## Setup

### Prerequisite

- AWS account
- Terraform
- [jrsonnet](https://github.com/CertainLach/jrsonnet)
- Node.JS (npm)
- Ruby

### Infrastructure

Deploy infrastructure using Terraform. This repository works as a terraform module:

```terraform
module "prd" {
  source = "github.com/sorah/publikes"

  iam_role_prefix = "PublikesPrd"
  name_prefix     = "publikes-prd"
  s3_bucket_name  = "..."
  app_domain      = "like.example.com"

  certificate_arn       = data.aws_acm_certificate.my-certificate.arn
  cloudfront_log_bucket = "example.s3.amazonaws.com"
  cloudfront_log_prefix = "like.example.com/"
}

# outputs:
# - module.prd.cloudfront_distribution_domain_name to create a DNS record
# - module.prd.cloudfront_distribution_id for deploy.rb (see below)
# - module.prd.lambda_function_url for ingestion webhook (see below)

```

### Web UI

```
cd ui/
npm i
vim .env.production.local
npm run build
ruby deploy.rb $S3_BUCKET_NAME $CLOUDFRONT_DISTRIBUTION_ID
```

Refer to [ui/.env](./ui/.env) for available environment variables.

### Secret

You need to manually setup AWS Secrets Manager Secret `{name_prefix}/secret` with following key-value values:

- `ingest_secret`: Secret string used for webhook. Send as `x-secret` in webhook requests to verify its authenticity.

### Liked Tweets Ingestion

To avoid paying 100 USD/mo for Twitter API, this system uses IFTTT to feed likes information to store. You can use [New liked tweet by you] trigger with [Make a web request] action.

- URL: `{lambda_function_uri}/publikes-ingest`
- Content-Type: application/json
- Headers: `x-secret: {secret}`
- Content: `{"url": "<<<{{LinkToTweet}}>>>"}`

## How it works

### Ingestion

The lambda function behind Function URL enqueues incoming tweet URL to the SQS queue. Then the messages will be consumed by an another Lambda function, and the included Tweet URLs are inserted into the latest page.

### Page Rotation

The page of tweet IDs are rotated every N tweets (`MAX_ITEMS_IN_HEAD`) or after 6 hours using [rotate-batch] Step Functions State Machine. This system carefully uses S3 for ingestion not to happen any data loss by ingesting into the single object (such as race condition and conflicts). Partial data are eventually completed, especially during the merge process of [rotate-batch] state machine run.

## License

MIT License

