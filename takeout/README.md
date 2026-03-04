# takeout: Download and sync publikes data


## Downloader

### Usage

```
S3_BUCKET=... AWS_REGION=... ruby takeout.rb TARGET_DIR
```

### Output

- `{TARGET_DIR}`
  - `tweets`
    - `{year}-{month}.jsonl` (e.g. 2025-06.jsonl), based on like timestamp (status `ts` field)
  - `media`
    - `{year}-{month}`, based on tweet timestamp
      - `{screen_name}.{tweet_id}.{media_type}-{num}.{extension}` (media type and num is taken by original s3 key)

#### Jsonl

Combine 2 objects into a single line and single JSON object:

- `.tweet`: `s3://{BUCKET}/private/statuses/{tweet_id}.json`
- `.media`: `s3://{BUCKET}/private/media/{tweet_id}/index.json`

#### Sync

- Use `s3:GetObject` to iterate batches and pages, instead of `s3:ListObjects`
  - Use threads to download in parallel
- Lazy load `tweets` jsonl when needed, retain IDs on memory
- save to jsonl file when missing items (don't append twice)
