#!/bin/bash

# Ensure the users directory exists and has the correct permissions
mkdir -p /srv/shiny-server/lacen/www/users
chown -R shiny:shiny /srv/shiny-server/lacen/www/users
chmod -R 777 /srv/shiny-server/lacen/www/users

# Start the cron service in the background
service cron start

# Start Shiny Server in the foreground
exec /usr/bin/shiny-server
