mhc2gcal.rb
===========

* Import MHC schedules into Google Calender

* mhc2gcal.rb was originally developed at http://nao.river24.net/blog/category/mhc2gcal/ and this version is forked to use "Google API Client" instead of gcalapi as the library because gcalapi is using deprecated APIs

SETUP
-----
* Install google-api-client

    % gem install google-api-client

* Regist this application and get the client ID and client secret from
  https://code.google.com/apis/console#access

* Authorize the application and generate .google-api.yaml

    % google-api oauth-2-login --scope=https://www.googleapis.com/auth/calendar --client-id=CLIENT_ID --client-secret=CLIENT_SECRET

* copy gcal.yaml to ~/.gcal

    % cp gcal.yaml ~/.gcal

* Modify ~/.gcal to specify your calender_id.  You can check the calender_id in calender setting tab on your google calender

* Enjoy!

USAGE
-----
* help option show you the usage

    % mhc2gcal.rb --help

TODO
----
* HTTP Proxy is temporally disabled
