#' Build a Docker image
#' 
#' This function builds a Docker image with the specified name and version.
#' 
#' @param image_name The name of the Docker image. Defaults to "default_image".
#' @param version The version of the Docker image. Defaults to "latest".
#' @param build_context The build context for the Docker image. Defaults to the current directory.
#' @examples
#' docker_build(image_name = "my_image", version = "1.0")
docker_build <- function(image_name = "default_image", version = "latest", build_context = ".") {
  # Combine image name and version
  full_image_name <- sprintf("%s:%s", image_name, version)
  
  # Build Docker image with version
  command <- sprintf("docker build -t %s %s", full_image_name, build_context)
  cat("Running command:", command, "\n")
  system(command)
}

#' Remove a Docker image
#' 
#' This function removes a Docker image with the specified name and version if it exists.
#' 
#' @param image_name The name of the Docker image.
#' @param version The version of the Docker image. Defaults to "latest".
#' @examples
#' docker_remove("my_image", "1.0")
docker_remove <- function(image_name, version = "latest") {
  if (docker_image_exists(image_name, version)) {
    full_image_name <- sprintf("%s:%s", image_name, version)
    command <- sprintf("docker rmi -f %s", full_image_name)
    cat("Removing image:", full_image_name, "\n")
    system(command)
  } else {
    cat("Image not found:", image_name, ":", version, "\n")
  }
}

#' List Docker images
#' 
#' This function lists all available Docker images.
#' 
#' @return A character vector of Docker images in the format "repository:tag".
#' @examples
#' docker_list_images()
docker_list_images <- function() {
  command <- "docker images --format '{{.Repository}}:{{.Tag}}'"
  result <- system(command, intern = TRUE)
  cat("Available Docker images:\n", paste(result, collapse = "\n"), "\n")
  return(result)
}

#' List Docker containers
#' 
#' This function lists all available Docker containers. Optionally, it can include stopped containers.
#' 
#' @param all Logical. If TRUE, includes stopped containers. Defaults to FALSE.
#' @return A character vector of Docker container names and their associated images.
#' @examples
#' docker_list_containers()
#' docker_list_containers(all = TRUE)
docker_list_containers <- function(all = FALSE) {
  flag <- if (all) "-a" else ""
  command <- sprintf("docker ps %s --format '{{.Names}} ({{.Image}})'", flag)
  result <- system(command, intern = TRUE)
  cat("Available Docker containers:\n", paste(result, collapse = "\n"), "\n")
  return(result)
}

#' Check if a Docker image exists
#' 
#' This function checks whether a Docker image with the specified name and version exists.
#' 
#' @param image_name The name of the Docker image.
#' @param version The version of the Docker image. Defaults to "latest".
#' @return TRUE if the image exists, FALSE otherwise.
#' @examples
#' docker_image_exists("my_image", "1.0")
docker_image_exists <- function(image_name, version = "latest") {
  full_image_name <- sprintf("%s:%s", image_name, version)
  images <- docker_list_images()
  return(full_image_name %in% images)
}

#' List running Docker containers
#' 
#' This function lists all currently running Docker containers.
#' 
#' @return A data frame containing container ID, image name, and container name for each running container.
#' @examples
#' docker_list_running_containers()
docker_list_running_containers <- function() {
  command <- "docker ps --format '{{.ID}} {{.Image}} {{.Names}}'"
  result <- system(command, intern = TRUE)
  if (length(result) == 0) {
    cat("No running containers found.\n")
    return(data.frame(ID = character(), Image = character(), Name = character(), stringsAsFactors = FALSE))
  }
  cat("Running containers:\n", paste(result, collapse = "\n"), "\n")
  
  # Parse the result into a data frame
  containers <- do.call(rbind, strsplit(result, " "))
  return(data.frame(ID = containers[, 1], Image = containers[, 2], Name = containers[, 3], stringsAsFactors = FALSE))
}

#' Stop a Docker container
#' 
#' This function stops a specific Docker container by its ID or name.
#' 
#' @param container_id_or_name The ID or name of the container to stop.
#' @examples
#' docker_stop_container("my_container")
docker_stop_container <- function(container_id_or_name) {
  command <- sprintf("docker stop %s", container_id_or_name)
  cat("Stopping container:", container_id_or_name, "\n")
  system(command)
}

#' Stop unnecessary Docker containers
#' 
#' This function stops all running Docker containers or filters by a specific image name.
#' 
#' @param image_name The name of the Docker image to filter by. Defaults to NULL (all containers).
#' @examples
#' docker_stop_unnecessary_containers()
#' docker_stop_unnecessary_containers(image_name = "my_image")
docker_stop_unnecessary_containers <- function(image_name = NULL) {
  containers <- docker_list_running_containers()
  
  if (nrow(containers) == 0) {
    cat("No containers to stop.\n")
    return()
  }
  
  # Filter containers by image name if provided
  if (!is.null(image_name)) {
    containers <- containers[containers$Image == image_name, ]
    if (nrow(containers) == 0) {
      cat("No containers found for image:", image_name, "\n")
      return()
    }
  }
  
  # Stop all matched containers
  for (container_id in containers$ID) {
    docker_stop_container(container_id)
  }
}

#' Prune unused Docker resources
#' 
#' This function stops all running containers, removes all containers, and prunes unused images, networks, and volumes.
#' 
#' @examples
#' docker_prune()
docker_prune <- function() {
  cat("Stopping all running containers...\n")
  system("docker ps -q | xargs docker stop")
  
  cat("Removing all containers...\n")
  system("docker ps -aq | xargs docker rm")
  
  cat("Pruning all unused images, containers, networks, and volumes...\n")
  system("docker system prune -a -f --volumes")
  
  cat("Cleanup complete.\n")
}


#' Run MFCL commands in Docker
#' 
#' This function runs MFCL-related commands inside a Docker container.
#' 
#' @param image_name The name of the Docker image.
#' @param commands A vector of command(s) to execute inside the container.
#' @param project_dir The base project directory to mount. Defaults to the current working directory.
#' @param sub_dirs A list of subdirectories for execution. Defaults to NULL (only the base directory).
#' @param parallel Whether to enable parallel execution. Defaults to FALSE.
#' @param cores The number of cores to use for parallel execution. Defaults to all available cores minus one.
#' @param verbose Whether to print the executed commands. Defaults to TRUE.
#' @param log_file The log file to save the output. Defaults to NULL (no log file).
#' @return A list of results from the executed commands.
#' @examples
#' docker_run_mfcl(image_name = "mfcl_image", commands = "./mfclo64 input_file.frq")
docker_run_mfcl <- function(
    image_name,            # Docker image name
    commands,              # Commands to execute inside the container
    project_dir = getwd(), # Base project directory (default: current working directory)
    sub_dirs = NULL,       # List of subdirectories for execution
    parallel = FALSE,      # Enable parallel execution
    cores = parallel::detectCores() - 1, # Number of cores for parallel execution
    verbose = TRUE,        # Print command details
    log_file = NULL        # Log file to save command outputs
) {
  # Path conversion for Docker (Windows and non-Windows)
  convert_path_for_docker <- function(path) {
    if (.Platform$OS.type == "windows") {
      path <- normalizePath(path, winslash = "/")
      path <- gsub("^([A-Za-z]):", "/mnt/\\1", path, perl = TRUE)
    } else {
      path <- normalizePath(path)
    }
    return(path)
  }
  
  # Helper function for setting default value
  `%||%` <- function(a, b) {
    if (!is.null(a)) a else b
  }
  
  # Check if project directory exists
  if (!dir.exists(project_dir)) {
    stop("The project directory does not exist: ", project_dir)
  }
  
  # Set sub_dirs to root if not provided
  sub_dirs <- sub_dirs %||% list("")
  
  # Validate subdirectories
  invalid_dirs <- vapply(sub_dirs, function(sub_dir) {
    sub_dir_path <- if (sub_dir != "") file.path(project_dir, sub_dir) else project_dir
    !dir.exists(sub_dir_path)
  }, logical(1))
  
  if (any(invalid_dirs)) {
    stop("The following subdirectories do not exist: ", paste(sub_dirs[invalid_dirs], collapse = ", "))
  }
  
  # Adjust commands length if necessary
  if (length(commands) == 1) {
    commands <- rep(commands, length(sub_dirs))
  } else if (length(commands) != length(sub_dirs)) {
    stop("The length of 'commands' must match the length of 'sub_dirs'.")
  }
  
  # Set default log file if verbose is FALSE and no log_file is provided
  if (!verbose && is.null(log_file)) {
    log_file <- file.path(project_dir, "mfcl_output.log")
  }
  
  # Pre-generate Docker commands
  docker_commands <- mapply(function(sub_dir, command) {
    sub_dir_path <- if (sub_dir != "") file.path(project_dir, sub_dir) else project_dir
    sub_dir_path_docker <- convert_path_for_docker(sub_dir_path)
    list(
      command = sprintf(
        "docker run --rm -v %s:%s -w %s %s %s",
        shQuote(sub_dir_path), shQuote(sub_dir_path_docker), shQuote(sub_dir_path_docker), image_name, command
      ),
      sub_dir = sub_dir_path
    )
  }, sub_dirs, commands, SIMPLIFY = FALSE)
  
  # Verbose output
  if (verbose) {
    cat("Executing the following Docker commands:\n")
    for (cmd in docker_commands) {
      cat(cmd$command, "\n")
    }
  }
  
  # Run commands sequentially or in parallel
  run_commands <- function(docker_cmds) {
    total_cmds <- length(docker_cmds)
    pb <- utils::txtProgressBar(min = 0, max = total_cmds, style = 3) # Progress bar
    
    # Shared progress counter for parallel execution
    progress_env <- new.env(parent = emptyenv())
    progress_env$progress <- 0
    
    update_progress <- function() {
      progress_env$progress <- progress_env$progress + 1
      utils::setTxtProgressBar(pb, progress_env$progress)
    }
    
    capture_output <- function(cmd_info, index) {
      cmd <- cmd_info$command
      sub_dir <- cmd_info$sub_dir
      
      # Redirect output to log file if verbose is FALSE
      if (!verbose) {
        cmd <- sprintf("%s >> %s 2>&1", cmd, shQuote(log_file))
      }
      
      # Capture output and error streams
      result <- tryCatch({
        output <- system(cmd, intern = TRUE)
        output
      }, error = function(e) {
        paste("Error:", e$message)
      })
      
      # Update progress bar
      update_progress()
      
      # Return detailed result
      return(list(
        command = cmd,
        sub_dir = sub_dir,
        index = index,
        output = result
      ))
    }
    
    if (.Platform$OS.type == "windows") {
      if (parallel) {
        cl <- parallel::makeCluster(cores)
        on.exit(parallel::stopCluster(cl))
        results <- parallel::parLapply(cl, seq_along(docker_cmds), function(i) {
          capture_output(docker_cmds[[i]], i)
        })
      } else {
        results <- lapply(seq_along(docker_cmds), function(i) {
          capture_output(docker_cmds[[i]], i)
        })
      }
    } else {
      if (parallel) {
        results <- parallel::mclapply(seq_along(docker_cmds), function(i) {
          res <- capture_output(docker_cmds[[i]], i)
          update_progress()
          res
        }, mc.cores = cores)
      } else {
        results <- lapply(seq_along(docker_cmds), function(i) {
          capture_output(docker_cmds[[i]], i)
        })
      }
    }
    
    close(pb) # Close progress bar
    return(results)
  }
  
  # Execute and return results
  results <- run_commands(docker_commands)
  return(results)
}

#' Create a Dockerfile with custom options
#' 
#' This function generates a Dockerfile for setting up an R environment with specified R and GitHub packages.
#' 
#' @param r_version The R version to install. Defaults to "latest".
#' @param r_packages A character vector of additional CRAN packages to install.
#' @param github_packages A character vector of additional GitHub repositories to install.
#' @param base_image The base Docker image. Defaults to "ubuntu:22.04".
#' @param output_file The name of the Dockerfile to generate. Defaults to "Dockerfile".
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


#' Pull a Docker image from Docker Hub
#' 
#' This function pulls a Docker image from Docker Hub 
#' 
#' @param image_name The name of the Docker image.
#' @param version The version of the Docker image. Defaults to "latest".
#' @examples
#' docker_pull("my_image", "1.0")
docker_pull <- function(image_name, version = "latest") {
  # Combine image name and version
  full_image_name <- sprintf("%s:%s", image_name, version)
  
  # Check if the image already exists locally
  image_exists <- function(image_name) {
    command <- sprintf("docker images -q %s", image_name)
    result <- system(command, intern = TRUE)
    return(length(result) > 0)
  }
  
  # Pull the image if it doesn't exist locally
  if (!image_exists(full_image_name)) {
    cat(sprintf("Image '%s' not found locally. Pulling from Docker Hub...\n", full_image_name))
    pull_command <- sprintf("docker pull %s", full_image_name)
    result <- system(pull_command, intern = TRUE)
    cat(result, sep = "\n")
  } else {
    cat(sprintf("Image '%s' already exists locally. No need to pull.\n", full_image_name))
  }
}



#' Push a Docker image to Docker Hub
#' 
#' This function pushes a Docker image to Docker Hub
#' 
#' @param local_image The name of the local Docker image.
#' @param remote_image The name of the remote Docker image.
#' @param username The Docker Hub username.
#' @param tag The tag of the Docker image. Defaults to "latest".
#' @examples 
#' docker_push("my_image", "my_image", "my_username", "1.0")
docker_push <- function(local_image, remote_image, username, tag = "latest") {
  # Combine image name and tag
  full_local_image <- sprintf("%s:%s", local_image, tag)
  full_remote_image <- sprintf("%s/%s:%s", username, remote_image, tag)
  
  # Tag the image for Docker Hub
  cat(sprintf("Tagging image: %s as %s\n", full_local_image, full_remote_image))
  system(sprintf("docker tag %s %s", full_local_image, full_remote_image))
  
  # Push the image to Docker Hub
  cat(sprintf("Pushing image: %s to Docker Hub\n", full_remote_image))
  system(sprintf("docker push %s", full_remote_image))
}

