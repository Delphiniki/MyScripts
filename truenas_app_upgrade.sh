#!/bin/bash

# This script uses Truenas API client to get list of all apps and upgrade them ,if there is  an upgrade available.

hostname=$(hostname)
apps=()

applist=$(midclt call app.query | jq -r '.[].name')  # create a list of all apps
for a in  "${applist[@]}"; do
  apps+=($a)
done

# Next upgrade apps if available:
for app in "${apps[@]}"; do

   upgrade=$(midclt call app.config $app | jq | grep is_upgrade | cut -d ":" -f2 | cut -d "," -f1 | tr -d ' ')  # test if app need upgrade

   if [ "$upgrade" == "true" ]; then
      echo "$app has Latest version."    # optional

else
      echo "$app Upgrade available."    # optional
      midclt call app.upgrade  $app    # upgrading the app
      sleep 2  # wait some time to upgrade
      version=$(midclt call app.config $app | jq | grep "version" | head -n4 | tail -n1 | cut -d ":" -f2 | tr -d '"' |  tr -d ' ')   # get last version
      logger "Upgraded $app to the latest version: $version"    # just logs the upgrade

      ### Optional : slack notification:
     # curl -X POST -H 'Content-type: application/json' \
         # --data '{"text":"Hostname: '$hostname', Application: '$app' was upgraded to latest version: '$version' !"}' \
         # https://hooks.slack.com/services/XXXXXXXXXXX/YYYYYYYYYYY/ZZZZZZZZZZZZ
   fi
done

exit 0
