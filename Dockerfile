
# Use the specified base image
FROM ubuntu:22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    R_VERSION=4.3.0 \
    R_PACKAGES="ggplot2 dplyr tidyverse remotes" \
    FLR_REPO="http://flr-project.org/R"

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    gcc \
    g++ \
    gfortran \
    tzdata \
    make \
    libc-dev \
    zlib1g-dev \
    libbz2-dev \
    liblzma-dev \
    libpcre2-dev \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libreadline-dev \
    libncurses5-dev \
    ca-certificates \
    libx11-dev \
    libxt-dev \
    libjpeg-dev \
    libpng-dev \
    libtiff5-dev \
    libgtk2.0-dev \
    libcairo2-dev \
    pandoc \
    pandoc-citeproc && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Set timezone (optional if tzdata prompts for configuration)
ENV TZ=Etc/UTC


# Install R
RUN wget https://cloud.r-project.org/src/base/R-4/R-${R_VERSION}.tar.gz && \
    tar -xvzf R-${R_VERSION}.tar.gz && \
    cd R-${R_VERSION} && \
    ./configure --enable-R-shlib && \
    make -j$(nproc) && \
    make install && \
    cd .. && \
    rm -rf R-${R_VERSION} R-${R_VERSION}.tar.gz

# Install R packages
RUN Rscript -e "install.packages(unlist(strsplit(Sys.getenv('R_PACKAGES'), ' ')), repos='http://cran.rstudio.com/')"

# Install FLCore package
RUN Rscript -e "install.packages('FLCore', repos=Sys.getenv('FLR_REPO'))"

# Install GitHub packages
RUN Rscript -e "remotes::install_github('rstudio/shiny') && remotes::install_github('tidyverse/dplyr')"

# Set working directory inside the container
WORKDIR /workspace

# Copy the entire project into the container
COPY .. /workspace

# Default command to allow Makefile-driven control
CMD ["make"]

