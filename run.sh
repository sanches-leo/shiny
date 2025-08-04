#!/bin/bash

# Start the cron service in the background
service cron start

# Start Shiny Server in the foreground
exec /usr/bin/shiny-server
