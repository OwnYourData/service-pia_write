FROM rocker/r-base
MAINTAINER "Christoph Fabianek" christoph@ownyourdata.eu

RUN apt-get update \
        && apt-get install -y --no-install-recommends \
                libcurl4-openssl-dev \
                libssl-dev \
                libssh2-1-dev \
                libxml2-dev \
                libsodium-dev \
        && rm -rf /var/lib/apt/lists/* \
        && R -e "install.packages(c( \
                'devtools', \
                'jsonlite', \
                'RCurl', \
                'data.table', \
                'digest', \
                'tidyr', \
                'sodium', \
                'shiny'), repos='http://cran.r-project.org')" \
        && R -e "devtools::install_github('ownyourdata/oydapp')" \
        && mkdir -p /srv-pia_write

RUN R -e "devtools::install_github('ownyourdata/oydapp', force=TRUE)"
USER docker

COPY script/run.sh /bin/run.sh
COPY script/*.R /srv-pia_write/
        
CMD ["/bin/bash"]
