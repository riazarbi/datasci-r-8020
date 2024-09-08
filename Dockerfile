FROM riazarbi/datasci-gui-minimal:20240908155628
LABEL authors="Riaz Arbi,Gordon Inggs"

USER root

# For TinyTex
ENV PATH=$PATH:/opt/TinyTeX/bin/x86_64-linux

# DEPENDENCIES ===================================================================
ADD init_kableextra.Rmd /

# INSTALL R PACKAGES ========================================================

COPY apt.txt .

RUN echo "Checking for 'apt.txt'..." \
        ; if test -f "apt.txt" ; then \
        apt-get update --fix-missing > /dev/null\
        && xargs -a apt.txt apt-get install --yes \
        && apt-get clean > /dev/null \
        && rm -rf /var/lib/apt/lists/* \
        && rm -rf /tmp/* \
        ; fi

# Install R dependencies
COPY install.R .
RUN if [ -f install.R ]; then R --quiet -f install.R; fi

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

# Increase Magick resource limits
RUN sed -i '/policy domain="resource" name="memory"/c\  <policy domain="resource" name="memory" value="10GiB"/>' /etc/ImageMagick-6/policy.xml
RUN sed -i '/policy domain="resource" name="disk"/c\  <policy domain="resource" name="disk" value="10GiB"/>' /etc/ImageMagick-6/policy.xml


# TEX AND MICROSOFT FONTS ================================================
# Install and setup Tex via tinytex
ENV CTAN_REPO="https://ctan.math.ca/tex-archive/systems/texlive/tlnet/"
RUN echo tmp && wget -qO- "https://yihui.org/tinytex/install-bin-unix.sh" \
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
 && /usr/local/bin/fix-permissions $HOME \
# R JAVA PATH FIX ========================================================
 && R CMD javareconf

# BACK TO NB_USER ========================================================
USER $NB_USER
