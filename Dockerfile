FROM riazarbi/datasci-gui-minimal:bionic

LABEL authors="Riaz Arbi,Gordon Inggs"

USER root

# ARGS ===========================================================================

ARG r_packages=" \
    devtools \
    tidyverse \
    arrow \
    reticulate \
    skimr \
  # Extrafont is for skimr
    extrafont \
    kableExtra \
    RPresto \
    ckanr \
    pryr \
    # h3 dependency
    digest \
    Rcpp \
    cli \
    # DB utils
    rJava \
    RJDBC \
    # graphics 
    plotly \
    # spatial
    #XML \
    #sf \
    "
RUN echo $r_packages

# For TinyTex
ENV PATH=$PATH:/opt/TinyTeX/bin/x86_64-linux

# For arrow to install bindings
ENV LIBARROW_DOWNLOAD=true

# DEPENDENCIES ===================================================================
ADD init_kableextra.Rmd /

RUN DEBIAN_FRONTEND=noninteractive \
    apt-get clean && \
    DEBIAN_FRONTEND=noninteractive \
    apt-get update && \
    apt-get install -y \
    libcairo2-dev \
    libudunits2-dev \
    libpq-dev \
    libmagick++-dev \
# pandoc for PDF rendering 
    pandoc \
# sf system packages
# && apt-get install -y software-properties-common \
# && add-apt-repository ppa:ubuntugis/ubuntugis-unstable \
 && DEBIAN_FRONTENG=noninteractive \
    apt-get update \
 && apt-get install -y \
    libudunits2-dev \
    libgdal-dev \
    libgeos-dev \
    libproj-dev \
    gdal-bin \
# All recommended R packages in apt \
    r-recommended \
# && apt-get purge -y software-properties-common \
# Clean out cache
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* 

# INSTALL R PACKAGES ========================================================
# CRAN =======================

RUN install2.r --error -s --deps TRUE $r_packages \
# For some reason sf needs to install after the preceding packages are completed
 && R -e "install.packages('sf')"

# NOT IN CRAN ================
#RUN R -e "remotes::install_github('r-spatial/sf', dependencies = TRUE)"
#RUN R -e "remotes::install_github('r-spatial/lwgeom', dependencies = TRUE)"

# h3-r for uber h3 hex traversal
RUN git clone --single-branch --branch "master" https://github.com/crazycapivara/h3-r.git \
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
 && echo "PATH=${PATH}" >> /usr/lib/R/etc/Renviron \
# Install and set up Microsoft fonts
 && echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | \
     debconf-set-selections \
 && DEBIAN_FRONTEND=noninteractive apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ttf-mscorefonts-installer \
# Knit a kableExtra sample Rmd to force download of relevant Tex packages
 && Rscript -e "rmarkdown::render('/init_kableextra.Rmd')" \
 && rm /init_kableextra.Rmd \
 && rm /init_kableextra.pdf \
# R JAVA PATH FIX ========================================================
 && R CMD javareconf

# BACK TO NB_USER ========================================================
USER $NB_USER
