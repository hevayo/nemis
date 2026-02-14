# Get user-scoped bearer token via password grant
POST {{is_url}}/oauth2/token
[Options]
insecure: true
[FormParams]
grant_type: password
username: {{test_username}}
password: {{test_password}}
client_id: {{consumer_key}}
client_secret: {{consumer_secret}}

HTTP 200
[Asserts]
jsonpath "$.access_token" exists
jsonpath "$.token_type" == "Bearer"
