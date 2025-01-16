# Define functions for Docker operations
docker_build <- function(image_name = "default_image", version = "latest", build_context = ".") {
  # Combine image name and version
  full_image_name <- sprintf("%s:%s", image_name, version)
  
  # Build Docker image with version
  command <- sprintf("docker build -t %s %s", full_image_name, build_context)
  cat("Running command:", command, "\n")
  system(command)
}

# Remove a Docker image if it exists
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



# Get a list of Docker images
docker_list_images <- function() {
  command <- "docker images --format '{{.Repository}}:{{.Tag}}'"
  result <- system(command, intern = TRUE)
  cat("Available Docker images:\n", paste(result, collapse = "\n"), "\n")
  return(result)
}



# Get a list of Docker containers
docker_list_containers <- function(all = FALSE) {
  flag <- if (all) "-a" else ""
  command <- sprintf("docker ps %s --format '{{.Names}} ({{.Image}})'", flag)
  result <- system(command, intern = TRUE)
  cat("Available Docker containers:\n", paste(result, collapse = "\n"), "\n")
  return(result)
}


# Check if a Docker image exists
docker_image_exists <- function(image_name, version = "latest") {
  full_image_name <- sprintf("%s:%s", image_name, version)
  images <- docker_list_images()
  return(full_image_name %in% images)
}


# List running containers
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

# Stop a specific container by ID or Name
docker_stop_container <- function(container_id_or_name) {
  command <- sprintf("docker stop %s", container_id_or_name)
  cat("Stopping container:", container_id_or_name, "\n")
  system(command)
}

# Stop all containers that match a specific condition
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


docker_prune <- function() {
  cat("Stopping all running containers...\n")
  system("docker ps -q | xargs docker stop")
  
  cat("Removing all containers...\n")
  system("docker ps -aq | xargs docker rm")
  
  cat("Pruning all unused images, containers, networks, and volumes...\n")
  system("docker system prune -a -f --volumes")
  
  cat("Cleanup complete.\n")
}


docker_run_mfcl <- function(
    image_name,            # Docker image name
    commands,              # Command(s) to execute inside the container
    project_dir = getwd(), # Base project directory (default: current working directory)
    sub_dirs = NULL,       # List of subdirectories for execution
    parallel = FALSE,      # Whether to enable parallel execution
    cores = parallel::detectCores() - 1, # Number of cores to use for parallel execution
    verbose = TRUE         # Whether to print the executed commands
) {
  # Check if the project directory exists
  if (!dir.exists(project_dir)) {
    stop("The project directory does not exist: ", project_dir)
  }
  
  # If no subdirectories are provided, assume the base project directory
  if (is.null(sub_dirs)) {
    sub_dirs <- list("")
  }
  
  # If commands is a single string, replicate it for all sub_dirs
  if (length(commands) == 1) {
    commands <- rep(commands, length(sub_dirs))
  }
  
  # Ensure commands match the number of sub_dirs
  if (length(commands) != length(sub_dirs)) {
    stop("The length of 'commands' must match the length of 'sub_dirs'.")
  }
  
  # Normalize the project directory path
  project_dir <- normalizePath(project_dir)
  
  # Function to run Docker for a single subdirectory and command
  run_docker_for_subdir <- function(sub_dir, command) {
    # Combine project directory with the subdirectory
    if (sub_dir != "") {
      sub_dir_path <- file.path(project_dir, sub_dir)
    } else {
      sub_dir_path <- project_dir
    }
    
    # Check if the combined directory exists
    if (!dir.exists(sub_dir_path)) {
      stop("The specified sub-directory does not exist: ", sub_dir_path)
    }
    
    # Normalize the subdirectory path
    sub_dir_path <- normalizePath(sub_dir_path)
    
    # Set the container's mount path to be the same as the host path
    container_path <- sub_dir_path
    
    # Construct the Docker command
    docker_command <- sprintf(
      "docker run --rm -v %s:%s -w %s %s %s",
      sub_dir_path, container_path, container_path, image_name, command
    )
    
    # Print the command for debugging if verbose is enabled
    if (verbose) {
      cat("Running Docker command for subdirectory:", sub_dir, "\n", docker_command, "\n")
    }
    
    # Execute the command
    result <- system(docker_command, intern = TRUE)
    
    # Return the result of the executed command
    return(list(sub_dir = sub_dir, command = command, result = result))
  }
  
  # Run commands sequentially or in parallel
  if (length(sub_dirs) == 1 || !parallel) {
    # Sequential execution
    results <- mapply(run_docker_for_subdir, sub_dirs, commands, SIMPLIFY = FALSE)
  } else {
    # Validate cores
    if (cores < 1) {
      stop("The number of cores must be at least 1.")
    }
    
    # Parallel execution using mclapply
    results <- parallel::mcmapply(
      run_docker_for_subdir, sub_dirs, commands, 
      SIMPLIFY = FALSE, mc.cores = cores
    )
  }
  
  return(results)
}

