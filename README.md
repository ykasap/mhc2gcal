# mhc2gcal

## SETUP

* Install google-api-client

> % gem install google-api-client

* Regist this application and get the client ID and client secret from
  https://code.google.com/apis/console#access

* Authorize the application and generate .google-api.yaml

> % google-api oauth-2-login --scope=https://www.googleapis.com/auth/calendar --client-id=CLIENT_ID --client-secret=CLIENT_SECRET

* copy gcal.yaml to ~/.gcal

> % cp gcal.yaml ~/.gcal

* Enjoy!

## USAGE

> mhc2gcal.rb --help

## TODO

* Bug: Duplication checking is failure with allday-event

* HTTP Proxy is temporally disabled
