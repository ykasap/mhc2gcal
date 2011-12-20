# mhc2gcal

## USAGE

1. Install google-api-client
> % gem install google-api-client

2. Regist this application on APIs console and get the client ID and secret from https://code.google.com/apis/console#access

3. Authorize the application and Generate .google-api.yaml
> % google-api oauth-2-login --scope=https://www.googleapis.com/auth/calendar --client-id=CLIENT_ID --client-secret=CLIENT_SECRET
