# hike-ui

## ui needs data - get it by querying dynamo directly
one way to get the data is to pull it directly from dynamo when the ui page loads
that can be done via cognito to permit unauthorized access to dynamo via the web
these two docs were helpful for setting up cognito to allow DynamoDB access
https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/GettingStarted.Js.Summary.html
https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Cognito.Credentials.html

created a cognito identity pool that allows unauth access
created a role that allows dynamo access
assigned that role to the cognito identity pool

## there has to be a better way - an api!
for one, I don't want the ui to even indicate that there is a dynamo table behind all of this. let alone show how it is being access via cognito - but it's right there in the code. my cognito pool id is visible in the script section of the index.html page. not sure if that is really a security hazard but there is a better way.....
the answer is to abstract all of the dynamo work to the api and have the ui call the api as needed.
the api ec2 instance now has rights to access dynamo as needed. I just need the ui to call the api for data.
not sure if this is enabled by default yet....it is not. fetching from the ui to
'http://ec2-54-89-84-212.compute-1.amazonaws.com:8081/stats' does not work...yet
maybe i need to be using the elastic ip of the api instance?
I think the reason this is not working is because it is the `browser` trying to call the api when it needs to be the server-side of the ui making the call.

## Using AWS Api Gateway
create an api gateway to sit in front of the api webserver and to broker calls to it.
i have a sample express api running on an ec2 instance but this could just as easily be a lamba or 2.
gateway supports either lambda or http backend `integrations`.

THIS DOCUMENTATION BELONGS IN THE LAMBDA repo
https://8tdvb17zme.execute-api.us-east-1.amazonaws.com/prod/stats
used a sample lambda application to create:
- api Gateway (along with a deployment and a stage named prod)
- lambda (along with a permission and an IAM role)

configured a gateway resource at GET /stats
which runs the lambda (no parameters needed) that queries dynamoDb for the overall stats
the api gateway handles the CORS so the gateway endpoint should work from the browser
