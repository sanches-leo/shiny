FROM rocker/shiny:latest

# Install system dependencies
RUN apt-get update && apt-get install -y     git     libcurl4-openssl-dev     libssl-dev     libxml2-dev     libfreetype6-dev     libpng-dev     libtiff5-dev     libjpeg-dev     libudunits2-dev     libglpk-dev     libgit2-dev     && rm -rf /var/lib/apt/lists/*

# Install R packages
RUN R -e "install.packages(c('BiocManager', 'remotes', 'shiny', 'shinyjs', 'dplyr'), repos = 'http://cran.us.r-project.org')"
RUN R -e "BiocManager::install('sanches-leo/lacen', ask = FALSE)"

# Copy application files
COPY app.R /srv/shiny-server/
COPY www /srv/shiny-server/www
# COPY users /srv/shiny-server/users
COPY .pass /srv/shiny-server/

# Change ownership of app files
RUN chown -R shiny:shiny /srv/shiny-server/

# Expose port
EXPOSE 3838

# Keep the container running without starting the app
# This allows you to 'docker exec' into it for debugging.
# CMD ["tail", "-f", "/dev/null"]

# Original command to run the app directly
CMD ["R", "-e", "shiny::runApp('/srv/shiny-server/app.R', host = '0.0.0.0', port = 3838)"]
