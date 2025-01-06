#!/bin/bash

### This script uses Truenas API client to get list of all apps and upgrade them ,if there is  an upgrade available.

hostname=$(hostname)
apps=()
flag=false  ## flag for slack notification
file="./attach"
echo "" > $file

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
      flag=true
      midclt call app.upgrade  $app    # upgrading the app
      sleep 3  # wait some time to upgrade
      version=$(midclt call app.config $app | jq | grep "version" | head -n4 | tail -n1 | cut -d ":" -f2 | tr -d '"' |  tr -d ' ')   # get last version
      logger "Upgraded $app to the latest version: $version"    # just logs the upgrade
      echo $app - version $version >> $file

   fi
done

### Slack notification with a list of upgraded apps
if $flag ; then
  curl -s \
  --form-string channels=<some channel> \   # <-- change channel here
  -F file=@$file \
  -F initial_comment="From hostname: $hostname.Upgraded apps list : " \
  -F filename="app_upgraded" \
  -F token=<xoxb-1111111111-2222222222222-abcdef123456789> \   # <-- change bot token here
  https://slack.com/api/files.upload
  flag=false
fi
rm $file
exit 0
