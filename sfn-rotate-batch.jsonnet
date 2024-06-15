local tfstate = std.parseJson(std.extVar('TFSTATE'));

local lambdaRetry = {
  ErrorEquals: [
    'Lambda.ServiceException',
    'Lambda.AWSLambdaException',
    'Lambda.SdkClientException',
    'Lambda.TooManyRequestsException',
  ],
  IntervalSeconds: 1,
  BackoffRate: 2,
  MaxAttempts: 20,
  JitterStrategy: 'FULL',
};

local definition = {
  StartAt: 'InvokeDetermineMergeability',
  States: {
    InvokeDetermineMergeability: {
      Type: 'Task',
      Resource: 'arn:aws:states:::lambda:invoke',
      Parameters: {
        FunctionName: tfstate.lambda_arn_action,
        Payload: {
          publikes_action: 'determine_mergeability',
        },
      },
      ResultSelector: {
        'result.$': '$.Payload',
      },
      ResultPath: '$.mergeability',
      Next: 'TestMergeability',
    },
    TestMergeability: {
      Type: 'Choice',
      Choices: [
        {
          Not: {
            Variable: '$.mergeability.result.mergeable',
            BooleanEquals: true,
          },
          Next: 'Skip',
        },
      ],
      Default: 'CheckExistingLock',
    },
    Skip: {
      Type: 'Succeed',
    },
    CheckExistingLock: {
      Type: 'Task',
      Parameters: {
        Bucket: tfstate.s3_bucket,
        Key: 'data/private/locks/current',
      },
      Resource: 'arn:aws:states:::aws-sdk:s3:getObject',
      Catch: [
        {
          ErrorEquals: [
            'States.TaskFailed',
          ],
          Next: 'SetLockId',
        },
      ],
      Next: 'LockOccupied',
    },
    SetLockId: {
      Type: 'Pass',
      Parameters: {
        lock: {
          'lock_id.$': "States.Format('sfn/rotate-batch/{}/{}', $$.Execution.Id, States.UUID())",
        },
      },
      Next: 'PlaceLock',
    },
    PlaceLock: {
      Type: 'Task',
      Parameters: {
        Bucket: tfstate.s3_bucket,
        Key: 'data/private/locks/current',
        ContentType: 'application/json',
        'Body.$': '$.lock',  // automatically JSON encoded
      },
      Resource: 'arn:aws:states:::aws-sdk:s3:putObject',
      ResultPath: null,
      Next: 'RetrieveLockOwnership',
    },
    RetrieveLockOwnership: {
      Type: 'Task',
      Parameters: {
        Bucket: tfstate.s3_bucket,
        Key: 'data/private/locks/current',
      },
      Resource: 'arn:aws:states:::aws-sdk:s3:getObject',
      ResultPath: '$.possibly_acquired_lock',
      ResultSelector: {
        'body.$': 'States.StringToJson($.Body)',
      },
      Retry: [
        {
          ErrorEquals: [
            'States.TaskFailed',
          ],
          BackoffRate: 2,
          IntervalSeconds: 2,
          MaxAttempts: 8,
          JitterStrategy: 'FULL',
        },
      ],
      Next: 'VerifyLockOwnership',
    },
    VerifyLockOwnership: {
      Type: 'Choice',
      Choices: [
        {
          Not: {
            Variable: '$.possibly_acquired_lock.body.lock_id',
            StringEqualsPath: '$.lock.lock_id',
          },
          Next: 'LockOccupied',
        },
      ],
      Default: 'InvokeCloseBatch',
    },
    LockOccupied: {
      Type: 'Succeed',
    },
    InvokeCloseBatch: {
      Type: 'Task',
      Resource: 'arn:aws:states:::lambda:invoke',
      Parameters: {
        FunctionName: tfstate.lambda_arn_action,
        Payload: {
          publikes_action: 'close_batch',
        },
      },
      Retry: [lambdaRetry],
      ResultSelector: {
        'result.$': '$.Payload',
      },
      ResultPath: '$.closed_batch',
      Next: 'ReleaseLock',
    },
    ReleaseLock: {
      Type: 'Task',
      Parameters: {
        Bucket: tfstate.s3_bucket,
        Key: 'data/private/locks/current',
      },
      Resource: 'arn:aws:states:::aws-sdk:s3:deleteObject',
      Retry: [
        {
          ErrorEquals: [
            'States.TaskFailed',
          ],
          BackoffRate: 2,
          IntervalSeconds: 2,
          MaxAttempts: 8,
          JitterStrategy: 'FULL',
        },
      ],
      ResultPath: null,
      Next: 'Wait',
    },
    Wait: {
      Type: 'Wait',
      Seconds: 120,
      Next: 'InvokeMergeBatch',
    },
    InvokeMergeBatch: {
      Type: 'Task',
      Resource: 'arn:aws:states:::lambda:invoke',
      Parameters: {
        FunctionName: tfstate.lambda_arn_action,
        Payload: {
          publikes_action: 'merge_batch',
          'batch_id.$': '$.closed_batch.result.closed_head_id',
        },
      },
      Retry: [lambdaRetry],
      ResultSelector: {
        'result.$': '$.Payload',
      },
      ResultPath: '$.merge',
      End: true,
    },
  },
};
{ definition: std.manifestJsonEx(definition, '  ') }
