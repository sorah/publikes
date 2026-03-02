local tfstate = std.parseJson(std.extVar('TFSTATE'));

local definition = {
  StartAt: 'Initialize',
  States: {
    Initialize: {
      Type: 'Pass',
      Result: [],
      ResultPath: '$.visited_status_ids',
      Next: 'InvokeStoreStatus',
    },
    InvokeStoreStatus: {
      Type: 'Task',
      Resource: 'arn:aws:states:::lambda:invoke',
      OutputPath: '$.Payload',
      Parameters: {
        Payload: {
          publikes_action: 'store_status',
          'status_id.$': '$.status_id',
          'visited_status_ids.$': '$.visited_status_ids',
        },
        FunctionName: tfstate.lambda_arn_action,
      },
      Retry: [
        {
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
        },
      ],
      Next: 'InvokeSaveMedia',
    },
    InvokeSaveMedia: {
      Type: 'Task',
      Resource: 'arn:aws:states:::lambda:invoke',
      ResultPath: null,
      Parameters: {
        Payload: {
          publikes_action: 'save_media',
          'status_id.$': '$.status_id',
        },
        FunctionName: tfstate.lambda_arn_action,
      },
      Retry: [
        {
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
        },
      ],
      Next: 'CheckQuotedTweet',
    },
    CheckQuotedTweet: {
      Type: 'Choice',
      Choices: [
        {
          Variable: '$.quoted_status_id',
          IsPresent: true,
          Next: 'PrepareNextIteration',
        },
      ],
      Default: 'Done',
    },
    PrepareNextIteration: {
      Type: 'Pass',
      Parameters: {
        'status_id.$': '$.quoted_status_id',
        'visited_status_ids.$': '$.visited_status_ids',
      },
      Next: 'InvokeStoreStatus',
    },
    Done: {
      Type: 'Succeed',
    },
  },
};


{ definition: std.manifestJsonEx(definition, '  ') }
