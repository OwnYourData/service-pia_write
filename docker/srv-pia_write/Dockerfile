FROM rocker/r-base
MAINTAINER "Christoph Fabianek" christoph@ownyourdata.eu

RUN apt-get update \
        && apt-get install -y --no-install-recommends \
                libcurl4-openssl-dev \
                libxml2-dev \
                libssl-dev \
        && rm -rf /var/lib/apt/lists/* \
        && R -e "install.packages(c( \
                'jsonlite', \
                'RCurl', \
                'httr', \
                'data.table', \
                'digest', \
                'tidyr'), repos='http://cran.r-project.org')" \
        && mkdir -p /srv-pia_write

USER docker

COPY script/run.sh /bin/run.sh
COPY script/*.R /srv-pia_write/
        
CMD ["/bin/bash"]
