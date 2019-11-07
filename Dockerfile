FROM riazarbi/r-base:latest

LABEL authors="Riaz Arbi,Gordon Inggs"

USER root

RUN DEBIAN_FRONTEND=noninteractive \
    apt-get clean && \
    DEBIAN_FRONTEND=noninteractive \
    apt-get update && \
    apt-get install -y \
    libcairo2-dev \
    libudunits2-dev \
    libpq-dev \
# sf system packages
 && apt-get install -y software-properties-common \
 && add-apt-repository ppa:ubuntugis/ubuntugis-unstable \
 && DEBIAN_FRONTENG=noninteractive \
    apt-get update \
 && apt-get install -y \
    libudunits2-dev \
    libgdal-dev \
    libgeos-dev \
    libproj-dev \
    gdal-bin \
 && apt-get purge -y software-properties-common \
# arrow system packages
 && wget -O /usr/share/keyrings/apache-arrow-keyring.gpg https://dl.bintray.com/apache/arrow/$(lsb_release --id --short | tr 'A-Z' 'a-z')/apache-arrow-keyring.gpg \
 && echo deb [arch=amd64 signed-by=/usr/share/keyrings/apache-arrow-keyring.gpg] https://dl.bintray.com/apache/arrow/$(lsb_release --id --short | tr 'A-Z' 'a-z')/ $(lsb_release --codename --short) main >> /etc/apt/sources.list.d/apache-arrow.list \
 && echo deb-src [signed-by=/usr/share/keyrings/apache-arrow-keyring.gpg] https://dl.bintray.com/apache/arrow/$(lsb_release --id --short | tr 'A-Z' 'a-z')/ $(lsb_release --codename --short) main >> /etc/apt/sources.list.d/apache-arrow.list \
 && cat /etc/apt/sources.list.d/apache-arrow.list \
 && DEBIAN_FRONTEND=noninteractive \
    apt update \
 && apt-get install -y -V libparquet-dev \
# Clean out cache
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

# R PACKAGES ============================================================

ARG r_packages="\
    tidyverse \
    arrow \
    reticulate \
    skimr \
    dataCompareR \
    sf \
    extrafont \
    "
# Extrafont is for skimr

RUN install2.r --error -n 3 -s --deps TRUE $r_packages 

# NOT IN CRAN

# h3-r for uber h3 hex traversal
# RUN git clone --single-branch --branch "feature/hex-ring" https://github.com/crazycapivara/h3-r.git \
RUN git clone --single-branch --branch "feature/polyfill" https://github.com/crazycapivara/h3-r.git \
  && cd h3-r \
  && chmod +x install-h3c.sh \
  && bash ./install-h3c.sh \
  && R -q -e 'devtools::install()' \
  && cd .. \
  && rm -rf h3-r \
# Python failover
  && python3 -m pip install h3

# TEX AND MICROSOFT FONTS ================================================

# Install and setup Tex via tinytex
ENV PATH=$PATH:/opt/TinyTeX/bin/x86_64-linux
RUN wget -qO- \
    "https://github.com/yihui/tinytex/raw/master/tools/install-unx.sh" | \
    sh -s - --admin --no-path \
    && mv ~/.TinyTeX /opt/TinyTeX \
    && /opt/TinyTeX/bin/*/tlmgr path add \
    && tlmgr install metafont mfware inconsolata tex ae parskip listings \
    && tlmgr path add \
    && Rscript -e "tinytex::r_texmf()" \
    && chown -R root:staff /opt/TinyTeX \
    && chown -R root:staff /usr/local/lib/R/site-library \
    && chmod -R g+w /opt/TinyTeX \
    && chmod -R g+wx /opt/TinyTeX/bin \
    && echo "PATH=${PATH}" >> /usr/lib/R/etc/Renviron
# Install and set up Microsoft fonts

RUN echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | \
    debconf-set-selections \
    && DEBIAN_FRONTEND=noninteractive apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ttf-mscorefonts-installer


USER $NB_USER
ENV PATH="${PATH}:/usr/lib/rstudio-server/bin"
