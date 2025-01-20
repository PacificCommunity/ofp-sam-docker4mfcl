#' Create a Dockerfile with custom options
#'
#' This function generates a Dockerfile for setting up an R environment with specified R and GitHub packages.
#'
#' @param r_version The R version to install. Defaults to "latest".
#' @param r_packages A character vector of additional CRAN packages to install.
#' @param github_packages A character vector of additional GitHub repositories to install.
#' @param base_image The base Docker image. Defaults to "ubuntu:22.04".
#' @param output_file The name of the Dockerfile to generate. Defaults to "Dockerfile".
#'
#' @examples
#' create_dockerfile(r_version = "4.2.3", r_packages = c("ggplot2", "dplyr"), github_packages = c("hadley/devtools"))

create_dockerfile <- function(
    r_version = "latest", # Default to the latest R version
    r_packages = c(),
    github_packages = c(),
    base_image = "ubuntu:22.04",
    output_file = "Dockerfile" # Always save as 'Dockerfile'
) {
  # Fixed package lists
  fixed_r_packages <- c("ggplot2", "dplyr", "tidyverse", "iterators", "remotes")
  fixed_github_packages <- c('PacificCommunity/ofp-sam-flr4mfcl')
  flr_repo <- "http://flr-project.org/R"

  # Combine fixed and additional packages
  all_r_packages <- unique(c(fixed_r_packages, r_packages))
  all_github_packages <- unique(c(fixed_github_packages, github_packages))

  # Convert package lists to string
  r_packages_str <- paste(all_r_packages, collapse = " ")
  github_packages_str <- paste(
    sprintf("remotes::install_github('%s')", all_github_packages),
    collapse = "; "
  )

  # Generate the Dockerfile content
  dockerfile_content <- sprintf(
    "# Use the specified base image
FROM %s

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive \\
    R_VERSION=%s \\
    R_PACKAGES=\"%s\" \\
    FLR_REPO=\"%s\"

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \\
    wget \\
    gcc \\
    g++ \\
    gfortran \\
    tzdata \\
    make \\
    libc-dev \\
    zlib1g-dev \\
    libbz2-dev \\
    liblzma-dev \\
    libpcre2-dev \\
    libcurl4-openssl-dev \\
    libssl-dev \\
    libxml2-dev \\
    libreadline-dev \\
    libncurses5-dev \\
    ca-certificates \\
    libx11-dev \\
    libxt-dev \\
    libjpeg-dev \\
    libpng-dev \\
    libtiff5-dev \\
    libgtk2.0-dev \\
    libcairo2-dev \\
    pandoc \\
    pandoc-citeproc && \\
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Install R
RUN wget https://cloud.r-project.org/src/base/R-4/R-${R_VERSION}.tar.gz && \\
    tar -xvzf R-${R_VERSION}.tar.gz && \\
    cd R-${R_VERSION} && \\
    ./configure --enable-R-shlib && \\
    make -j$(nproc) && \\
    make install && \\
    cd .. && \\
    rm -rf R-${R_VERSION} R-${R_VERSION}.tar.gz

# Install R packages
RUN Rscript -e \"install.packages(unlist(strsplit(Sys.getenv('R_PACKAGES'), ' ')), repos='http://cran.rstudio.com/')\"

# Install FLCore package
RUN Rscript -e \"install.packages('FLCore', repos=Sys.getenv('FLR_REPO'))\"

# Install GitHub packages
RUN Rscript -e \"%s\"

# Set working directory inside the container
WORKDIR /workspace

# Copy the entire project into the container
COPY .. /workspace

# Default command to allow Makefile-driven control
CMD [\"make\"]",
    base_image,
    r_version,
    r_packages_str,
    flr_repo,
    github_packages_str
  )

  # Write the content to a Dockerfile
  writeLines(dockerfile_content, con = output_file)
}
