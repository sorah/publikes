local tfstate = std.parseJson(std.extVar('TFSTATE'));

local definition = {
  StartAt: 'InvokeStoreStatus',
  States: {
    InvokeStoreStatus: {
      Type: 'Task',
      Resource: 'arn:aws:states:::lambda:invoke',
      OutputPath: '$.Payload',
      Parameters: {
        Payload: {
          publikes_action: 'store_status',
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
      End: true,
    },
  },
};


{ definition: std.manifestJsonEx(definition, '  ') }
