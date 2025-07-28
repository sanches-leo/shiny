FROM rocker/shiny:latest

# Install system dependencies
RUN apt-get update && apt-get install -y     cron     git     libcurl4-openssl-dev     libssl-dev     libxml2-dev     libfreetype6-dev     libpng-dev     libtiff5-dev     libjpeg-dev     libudunits2-dev     libglpk-dev     libgit2-dev     && rm -rf /var/lib/apt/lists/*

# Install R packages
RUN R -e "options(timeout = 1200); install.packages(c('BiocManager', 'remotes', 'shiny', 'shinyjs', 'dplyr', 'markdown'), repos = 'http://cran.us.r-project.org', lib = '/usr/local/lib/R/site-library')"
RUN R -e "options(timeout = 1200); BiocManager::install('sanches-leo/lacen', ask = FALSE, lib = '/usr/local/lib/R/site-library')"

# Copy application files
COPY app.R /srv/shiny-server/
COPY www /srv/shiny-server/www
# COPY users /srv/shiny-server/users
COPY .pass /srv/shiny-server/
COPY cleanup.sh /srv/shiny-server/
COPY crontab /etc/cron.d/cleanup-cron

# Give execution rights to the cron job and apply it
RUN chmod 0644 /etc/cron.d/cleanup-cron
RUN crontab /etc/cron.d/cleanup-cron

# Change ownership of app files
RUN chown -R shiny:shiny /srv/shiny-server/

# Expose port
EXPOSE 3838

# Start cron service and then run the app
CMD service cron start && R -e "shiny::runApp('/srv/shiny-server/app.R', host = '0.0.0.0', port = 3838)"
