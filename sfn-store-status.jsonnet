local tfstate = std.parseJson(std.extVar('TFSTATE'));

local definition = {
  StartAt: 'Initialize',
  States: {
    Initialize: {
      Type: 'Pass',
      Result: [],
      ResultPath: '$.visited_status_ids',
      Next: 'DefaultNoOverwrite',
    },
    DefaultNoOverwrite: {
      Type: 'Choice',
      Choices: [
        {
          Variable: '$.no_overwrite',
          IsPresent: true,
          Next: 'InvokeStoreStatus',
        },
      ],
      Default: 'SetNoOverwriteFalse',
    },
    SetNoOverwriteFalse: {
      Type: 'Pass',
      Result: false,
      ResultPath: '$.no_overwrite',
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
          'no_overwrite.$': '$.no_overwrite',
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
      Default: 'SaveMedia',
    },
    PrepareNextIteration: {
      Type: 'Pass',
      Parameters: {
        'status_id.$': '$.quoted_status_id',
        'visited_status_ids.$': '$.visited_status_ids',
        'no_overwrite.$': '$.no_overwrite',
      },
      Next: 'InvokeStoreStatus',
    },
    SaveMedia: {
      Type: 'Map',
      ItemsPath: '$.visited_status_ids',
      ItemSelector: {
        'status_id.$': '$$.Map.Item.Value',
        'no_overwrite.$': '$.no_overwrite',
      },
      ItemProcessor: {
        ProcessorConfig: {
          Mode: 'INLINE',
        },
        StartAt: 'InvokeSaveMedia',
        States: {
          InvokeSaveMedia: {
            Type: 'Task',
            Resource: 'arn:aws:states:::lambda:invoke',
            Parameters: {
              Payload: {
                publikes_action: 'save_media',
                'status_id.$': '$.status_id',
                'no_overwrite.$': '$.no_overwrite',
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
            End: true,
          },
        },
      },
      MaxConcurrency: 0,
      ResultPath: null,
      Next: 'Done',
    },
    Done: {
      Type: 'Succeed',
    },
  },
};


{ definition: std.manifestJsonEx(definition, '  ') }
