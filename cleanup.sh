#!/bin/bash

find /srv/shiny-server/users/ -mindepth 1 -maxdepth 1 -type d -atime +7 ! -name 'test' -exec rm -rf {} \;
