FROM riazarbi/datasci-gui-minimal:20211027100235
LABEL authors="Riaz Arbi,Gordon Inggs"

USER root

# ARGS ===========================================================================

ARG r_packages=" \
    devtools \
    tidyverse \
    arrow \
    reticulate \
    skimr \
    caret \
    openxlsx \
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
    sf \
    drake \
    #targets \ COMMENT: using github for now to benefit from arrow support
    tarchetypes \
    "
RUN echo $r_packages
RUN echo $R_LIBS_SITE 
# For TinyTex
ENV PATH=$PATH:/opt/TinyTeX/bin/x86_64-linux

# For arrow to install bindings
ENV LIBARROW_DOWNLOAD=true
ENV LIBARROW_MINIMAL=false

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
    libzmq3-dev \
# pandoc for PDF rendering
    pandoc \
# for pkgdown
    libharfbuzz-dev libfribidi-dev \
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
# && apt-get purge -y software-properties-common \
# Clean out cache
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* \
 && rm -rf /tmp/*

# Increase Magick resource limits
RUN sed -i '/policy domain="resource" name="memory"/c\  <policy domain="resource" name="memory" value="10GiB"/>' /etc/ImageMagick-6/policy.xml
RUN sed -i '/policy domain="resource" name="disk"/c\  <policy domain="resource" name="disk" value="10GiB"/>' /etc/ImageMagick-6/policy.xml

# INSTALL R PACKAGES ========================================================
# CRAN =======================

RUN  install2.r --skipinstalled --error  --ncpus 3 --deps TRUE -l $R_LIBS_SITE  $r_packages 

# NOT IN CRAN ================
RUN R -e "remotes::install_github('ropensci/targets', dependencies = TRUE)" \
 && rm -rf /tmp/*
#RUN R -e "remotes::install_github('r-spatial/lwgeom', dependencies = TRUE)"

# TEMPORARY PATCH FOR AWS S3 R PACKAGE NOT WORKING WITH NEW REGIONS ==========
RUN R -e "remotes::install_github('cityofcapetown/aws.s3.patch', dependencies = TRUE)" \
 && rm -rf /tmp/*

# h3-r for uber h3 hex traversal
RUN git clone --single-branch --branch "master" https://github.com/crazycapivara/h3-r.git \
  && cd h3-r \
  && chmod +x install-h3c.sh \
  && bash ./install-h3c.sh \
  && R -q -e 'devtools::install()' \
  && cd .. \
  && rm -rf h3-r \
# Python failover
  && python3 -m pip install h3 \
  && rm -rf /tmp/*

# TEX AND MICROSOFT FONTS ================================================
# Install and setup Tex via tinytex
ENV CTAN_REPO="https://ctan.math.ca/tex-archive/systems/texlive/tlnet/"
RUN echo tmp && wget -qO- "https://yihui.org/tinytex/install-unx.sh" \
  | sh -s - --admin --no-path

RUN mv ~/.TinyTeX /opt/TinyTeX \
 && /opt/TinyTeX/bin/*/tlmgr path add 

RUN tlmgr install metafont mfware inconsolata tex ae parskip listings colortbl makeindex \
 && tlmgr path add 

RUN Rscript -e "tinytex::r_texmf()" 
RUN chmod -R g+w /opt/TinyTeX 
RUN chmod -R g+wx /opt/TinyTeX/bin 
RUN echo "PATH=${PATH}" >> /usr/lib/R/etc/Renviron 

# Install and set up Microsoft fonts
RUN echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | \
     debconf-set-selections 
RUN DEBIAN_FRONTEND=noninteractive apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ttf-mscorefonts-installer \
 # Clean out cache
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* \
 && rm -rf /tmp/*

# Knit a kableExtra sample Rmd to force download of relevant Tex packages
RUN Rscript -e "rmarkdown::render('/init_kableextra.Rmd')" \
 && rm /init_kableextra.Rmd \
 && rm /init_kableextra.pdf \
# Clean out cache
 && rm -rf /tmp/*
 
# PYTHON REQUIREMENTS FOR CCT DB-UTILS ===================================
RUN python3 -m pip install "pandas>=1.2.0" \
 && python3 -m pip install "minio>=7.0.1" \
 && python3 -m pip install "pyodbc>=4.0.25" \
 && python3 -m pip install "pyhdb>=0.3.4" \
 && python3 -m pip install  "python-magic>=0.4.15" \
 && python3 -m pip install "pyarrow>=3.0.0" \
 && python3 -m pip install "fsspec>=0.8.5" \
 && python3 -m pip install "s3fs>=0.5.2" \
# R JAVA PATH FIX ========================================================
 && R CMD javareconf

# BACK TO NB_USER ========================================================
USER $NB_USER
