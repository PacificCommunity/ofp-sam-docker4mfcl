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
#'
#' @return A list of results from the executed commands.
#'
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
        list(output = output, error = NULL)
      }, error = function(e) {
        list(output = NULL, error = e$message)
      })

      # Return detailed result
      return(list(
        command = cmd,
        sub_dir = sub_dir,
        index = index,
        output = result$output,
        error = result$error
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
          capture_output(docker_cmds[[i]], i)
        }, mc.cores = cores)
      } else {
        results <- lapply(seq_along(docker_cmds), function(i) {
          capture_output(docker_cmds[[i]], i)
        })
      }
    }

    return(results)
  }

  # Execute and return results
  results <- run_commands(docker_commands)
  return(results)
}
