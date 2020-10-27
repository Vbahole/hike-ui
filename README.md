# hike-ui

these two docs were helpful for setting up cognito to allow DynamoDB access
https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/GettingStarted.Js.Summary.html
https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Cognito.Credentials.html

created a cognito identity pool that allows unauth access
created a role that allows dynamo access
assigned that role to the cognito identity pool
