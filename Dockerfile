FROM rocker/shiny:latest

# Install system dependencies
RUN apt-get update && apt-get install -y     cron     git     libcurl4-openssl-dev     libssl-dev     libxml2-dev     libfreetype6-dev     libpng-dev     libtiff5-dev     libjpeg-dev     libudunits2-dev     libglpk-dev     libgit2-dev     && rm -rf /var/lib/apt/lists/*

# Install R packages
RUN sudo su - -c "R -e \"options(timeout = 1200); install.packages(c('BiocManager', 'remotes', 'shiny', 'shinyjs', 'dplyr', 'markdown', 'future', 'promises'), repos = 'http://cran.us.r-project.org', lib = '/usr/local/lib/R/site-library')\""
RUN sudo su - -c "R -e \"options(timeout = 1200); BiocManager::install('sanches-leo/lacen', ask = FALSE, lib = '/usr/local/lib/R/site-library')\""

# Copy your custom shiny-server configuration file to the correct location
COPY shiny-server.conf /etc/shiny-server/shiny-server.conf

# Create a directory for your app
RUN mkdir -p /srv/shiny-server/lacen

# Copy your application files into the app directory
COPY app.R /srv/shiny-server/lacen/
COPY www /srv/shiny-server/lacen/www
COPY .pass /srv/shiny-server/lacen/
COPY cleanup.sh /srv/shiny-server/lacen/

# Create and set permissions for the users directory
RUN mkdir -p /srv/shiny-server/lacen/www/users && \
    chown -R shiny:shiny /srv/shiny-server/lacen/www/users && \
    chmod -R 777 /srv/shiny-server/lacen/www/users

# Set up the cron job
COPY crontab /etc/cron.d/cleanup-cron
RUN chmod 0644 /etc/cron.d/cleanup-cron && \
    crontab /etc/cron.d/cleanup-cron

# Copy the startup script
COPY run.sh /usr/bin/run.sh
RUN chmod +x /usr/bin/run.sh

# Change ownership of the app directory so the 'shiny' user can run it
RUN chown -R shiny:shiny /srv/shiny-server/

# Expose the port Shiny Server listens on
EXPOSE 3838

# Use the startup script as the container's command
CMD ["/usr/bin/run.sh"]