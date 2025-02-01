#!/bin/bash

### This script uses Truenas API client to get list of all apps and upgrade them ,if there is  an upgrade available.
### Mostly i use it as a cron job .Run as root .
### Created by Nikolay Chotrov (2025) ####

hostname=$(hostname)
#apps=()
flag=false  ## flag for slack notification
file="./attach"
echo "" > $file  # creates a file containing a list of upgraded apps .Just for notification attachment

midclt call catalog.sync > /dev/null   # sync app catalog
applist=$(midclt call app.query | jq -r '.[] | select(.custom_app != true and .upgrade_available == true) | "\(.name)"')  # create a list of upgradeable, non-custom, apps

if [ -z "$applist" ]; then
    echo "No upgradeable apps found."
    exit 0
fi

### Next upgrade apps if available:
echo "$applist" | while IFS= read -r app; do
    # flag=true   ## use notification
    echo "Upgrading $app"
    midclt call app.upgrade "$app" > /dev/null    # upgrading the app
    sleep 3  # wait some time to upgrade
    version=$(midclt call app.query |  jq -r '.[] | select(.name == "$app") | "\(.version)"')  # get the latest version
    echo "$app - version $version" >> $file  # log the upgraded app and its version
done

### Slack notification with a list of upgraded apps
if $flag ; then
  curl -s \
  --form-string channels=<some channel> \   # <-- change channel here
  -F file=@$file \
  -F initial_comment="From hostname: $hostname.Upgraded apps list : " \
  -F filename="app_upgraded" \
  -F token=<xoxb-1111111111-2222222222222-abcdef123456789> \   # <-- change bot token here
  https://slack.com/api/files.upload >/dev/null 2>&1
  flag=false
fi
rm $file
exit 0
