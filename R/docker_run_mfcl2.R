#' Run MFCL commands in Docker v2
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
#' docker_run_mfcl2(image_name = "mfcl_image", commands = "./mfclo64 input_file.frq")
#'
#' @export

docker_run_mfcl2 <- function(
    image_name,
    commands,
    project_dir = getwd(),
    sub_dirs = NULL,
    parallel = FALSE,
    cores = parallel::detectCores() - 1,
    verbose = TRUE,
    log_file = NULL
) {
  `%||%` <- function(a, b) if (!is.null(a)) a else b
  
  # ------------------------------------------------------------------
  # 1) Validate inputs
  # ------------------------------------------------------------------
  if (!dir.exists(project_dir)) {
    stop("The project directory does not exist: ", project_dir)
  }
  
  sub_dirs <- sub_dirs %||% list("")
  invalid_dirs <- vapply(sub_dirs, function(sd) {
    sd_path <- if (nzchar(sd)) file.path(project_dir, sd) else project_dir
    !dir.exists(sd_path)
  }, logical(1))
  if (any(invalid_dirs)) {
    stop("Subdirectories do not exist: ", paste(sub_dirs[invalid_dirs], collapse = ", "))
  }
  
  if (length(commands) == 1) {
    commands <- rep(commands, length(sub_dirs))
  } else if (length(commands) != length(sub_dirs)) {
    stop("The length of 'commands' must match the length of 'sub_dirs'.")
  }
  
  if (!verbose && is.null(log_file)) {
    log_file <- file.path(project_dir, "mfcl_output.log")
  }
  
  # ------------------------------------------------------------------
  # 2) Linux/macOS approach: volume mount (with optional Docker socket mount)
  # ------------------------------------------------------------------
  convert_path_for_docker <- function(path) {
    normalizePath(path)
  }
  
  run_single_subdir_volume <- function(sd, cmd) {
    sd_path <- if (nzchar(sd)) file.path(project_dir, sd) else project_dir
    sd_path_docker <- convert_path_for_docker(sd_path)
    
    # Check if the host's Docker socket exists; if so, mount it to avoid Docker-in-Docker issues.
    docker_socket <- "/var/run/docker.sock"
    if (file.exists(docker_socket)) {
      socket_mount <- sprintf("-v %s:%s", shQuote(docker_socket), shQuote(docker_socket))
    } else {
      socket_mount <- ""
    }
    
    docker_cmd <- sprintf(
      "docker run --rm -v %s:%s %s -w %s %s %s",
      shQuote(sd_path),              # mount the host directory
      shQuote(sd_path_docker),       # to the same path in container
      socket_mount,                  # optionally mount docker socket if available
      shQuote(sd_path_docker),       # set working directory
      image_name,                    # use specified image
      cmd                            # command to execute
    )
    
    if (!verbose) {
      docker_cmd <- sprintf("%s >> %s 2>&1", docker_cmd, shQuote(log_file))
    }
    
    res <- tryCatch({
      out <- system(docker_cmd, intern = TRUE)
      list(output = out, error = NULL)
    }, error = function(e) {
      list(output = NULL, error = e$message)
    })
    
    list(
      sub_dir = sd,
      command = docker_cmd,
      output  = res$output,
      error   = res$error
    )
  }
  
  # ------------------------------------------------------------------
  # 3) Windows approach: short local path + copy approach
  #
  #    => Creates one container per subdirectory, then removes it.
  # ------------------------------------------------------------------
  run_single_subdir_copy_win <- function(sd, cmd) {
    sd_path <- if (nzchar(sd)) file.path(project_dir, sd) else project_dir
    
    # 3a) Create a short local base
    short_base <- "C:/mfcl_temp"
    if (!dir.exists(short_base)) {
      dir.create(short_base, showWarnings = FALSE, recursive = TRUE)
    }
    
    # 3b) Make a unique subfolder inside short_base
    sub_temp <- file.path(short_base, paste0("subdir_", as.integer(Sys.time()), "_", sample(1000:9999, 1)))
    dir.create(sub_temp, recursive = TRUE, showWarnings = FALSE)
    
    # 3c) Copy *contents* of the real sub_dir to sub_temp
    copy_in <- function(from, to) {
      files <- list.files(from, all.files = TRUE, full.names = TRUE, no.. = TRUE)
      if (length(files) > 0) file.copy(files, to, recursive = TRUE)
    }
    copy_in(sd_path, sub_temp)
    
    # 3d) Start container
    container_name <- paste0("mfcl_sub_", as.integer(Sys.time()), "_", sample(1000:9999, 1))
    run_cmd <- sprintf("docker run -d --name %s %s tail -f /dev/null", container_name, image_name)
    if (verbose) cat("[Start container] ", run_cmd, "\n")
    
    container_id <- tryCatch({
      system(run_cmd, intern = TRUE)
    }, error = function(e) e$message)
    
    # 3e) Docker cp from sub_temp => container:/jobs
    copy_in_cmd <- sprintf('docker cp "%s/." "%s:/jobs"', sub_temp, container_name)
    if (verbose) cat("[Copy to container] ", copy_in_cmd, "\n")
    system(copy_in_cmd, intern = FALSE)
    
    # 3f) Run command inside /jobs
    if (!verbose) {
      c_log <- "/jobs/temp_output.log"
      exec_cmd <- sprintf('docker exec %s sh -c "cd /jobs && %s >> %s 2>&1"', container_name, cmd, c_log)
    } else {
      exec_cmd <- sprintf('docker exec %s sh -c "cd /jobs && %s"', container_name, cmd)
    }
    if (verbose) cat("[Exec cmd] ", exec_cmd, "\n")
    
    result <- tryCatch({
      system(exec_cmd, intern = TRUE)
    }, error = function(e) e$message)
    
    # 3g) Copy results back from container:/jobs => sub_temp
    copy_out_cmd <- sprintf('docker cp "%s:/jobs/." "%s"', container_name, sub_temp)
    if (verbose) cat("[Copy from container] ", copy_out_cmd, "\n")
    system(copy_out_cmd, intern = FALSE)
    
    # 3h) Remove the container right away
    remove_cmd <- sprintf("docker rm -f %s", container_name)
    if (verbose) cat("[Remove container] ", remove_cmd, "\n\n")
    system(remove_cmd, intern = FALSE)
    
    # 3i) If not verbose, merge logs
    if (!verbose) {
      c_log_local <- file.path(sub_temp, "temp_output.log")
      if (file.exists(c_log_local)) {
        cat(readLines(c_log_local), sep = "\n", file = log_file, append = TRUE)
        file.remove(c_log_local)
      }
    }
    
    # 3j) Copy updated results from sub_temp => original subdirectory
    copy_in(sub_temp, sd_path)
    
    # 3k) Clean up short local folder
    unlink(sub_temp, recursive = TRUE, force = TRUE)
    
    list(
      sub_dir = sd,
      command = cmd,
      output  = result,
      error   = NULL
    )
  }
  
  # ------------------------------------------------------------------
  # 4) Orchestrate (parallel or sequential)
  # ------------------------------------------------------------------
  run_commands <- function() {
    do_one <- function(i) {
      sd  <- sub_dirs[[i]]
      cmd <- commands[[i]]
      if (.Platform$OS.type == "windows") {
        # Use the short-path approach (one container per subdir)
        run_single_subdir_copy_win(sd, cmd)
      } else {
        # Use the volume mount approach with optional docker socket mount
        run_single_subdir_volume(sd, cmd)
      }
    }
    
    if (parallel) {
      if (.Platform$OS.type == "windows") {
        cl <- parallel::makeCluster(cores)
        on.exit(parallel::stopCluster(cl))
        results <- parallel::parLapply(cl, seq_along(sub_dirs), do_one)
      } else {
        results <- parallel::mclapply(seq_along(sub_dirs), do_one, mc.cores = cores)
      }
    } else {
      results <- lapply(seq_along(sub_dirs), do_one)
    }
    results
  }
  
  # ------------------------------------------------------------------
  # 5) Verbose summary
  # ------------------------------------------------------------------
  if (verbose) {
    cat("docker_run_mfcl2: Executing commands in subdirectories.\n")
    for (i in seq_along(sub_dirs)) {
      cat(sprintf("  Subdirectory: %s\n", sub_dirs[[i]]))
      cat(sprintf("  Command:      %s\n\n", commands[[i]]))
    }
    if (.Platform$OS.type == "windows") {
      cat("  => Windows: using separate containers per subdirectory.\n",
          "     (Short local path 'C:/mfcl_temp' to avoid path-too-long.)\n",
          "     Container is removed immediately after each subdirectory.\n\n")
    } else {
      cat("  => Linux/macOS: volume mount approach (docker run --rm) with optional docker socket mount.\n\n")
    }
  }
  
  # ------------------------------------------------------------------
  # 6) Execute
  # ------------------------------------------------------------------
  results <- run_commands()
  return(results)
}
