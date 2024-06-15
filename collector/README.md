# Publikes Collector

## bin/insert-batch

1. fail if `data/private/locks/current` exists 
1. put `data/private/locks/current` with `lock_id`=`bin/insert-batch/{hostname}/{now}/{random}`
1. check `data/private/locks/current` has expected content, otherwise fail
1. Get `data/public/current.json`
1. Update `data/public/batches/{new_last_id}.json` with `next`=`{current_last_id}`
1. Update `data/public/current.json` with `last`=`{new_last_id}`
1. Delete `data/private/locks/current`

## Step Functions state machines

### rotate-batch

1. fail if `data/private/locks/current` exists
1. put `data/private/locks/current` with `lock_id`=`sfn/rotate-batch/{sfn_id}`
1. check `data/private/locks/current` has expected content, otherwise fail
1. trigger __close_batch__
1. delete `data/private/locks/current`
1. wait 2 min
1. trigger __merge_batch__

## store-status

1. trigger __store_status__

## Lambda function actions

### publikes_action=store_status | bin/store-status 

いちおうかいた

Input: `status_id`

1. Merge `data/private/statuses/{id}.json` with `fxtwitter_data` and set `complete`=true

### publikes_action=close_batch | bin/close-batch

いちおうかいた

Input: None, Output: `current_was`, `current`, `closed_head_id`, `new_head_id`

1. TODO: Perform lock in state machine
1. Get `data/public/current.json` for `closing_head_id`
1. Create `data/public/batches/{new_head_id}.json` with `head`=true,`next`=`{closing_head_id}`
1. Update `data/public/current.json` with `last`=`{closing_head_id}`,`head`=`{new_head_id}`
1. Return `{closing_head_id}` and `{new_head_id}`

### publikes_action=merge_batch | bin/merge-batch

いちおうかいた

Input: `batch_id`, Output: `batch_id`

1. Get `data/public/batches/{batch_id}.json`
1. Read all pages by written order (`data/public/pages/head/{batch_id}/{page}.json`) and merge into larger pages
1. List prefix `data/public/pages/head/{batch_id}/` and merge missing items into the new first page
1. Put pages into `data/public/pages/merged/{batch_id}/{page}.json`
1. Replace `data/public/batches/{batch_id}.json` with new pages
1. Delete `data/public/pages/head/{batch_id}/*`

### `requestContext` (object) - Process function URL request

いちおうかいた

1. Validate secret
1. Insert request into FIFO SQS queue
   - `id`
   - `ts`
1. Return 20x Accepted

### `Records` (array) | bin/insert-status

いちおうかいた

Input: `status_ids`

1. Read `data/public/current.json` for `head_batch_id`
1. Get `data/public/statuses/{status_id}.json` and return if it exists
1. Get `data/public/batches/{head_batch_id}.json`
1. Put `data/public/pages/head/{head_batch_id}/{status_id}.json`
1. Update `data/public/batches/{head_batch_id}.json`
1. Trigger store_status state machine
