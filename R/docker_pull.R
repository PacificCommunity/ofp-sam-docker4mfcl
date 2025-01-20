#' Pull a Docker image from Docker Hub
#'
#' This function pulls a Docker image from Docker Hub
#'
#' @param image_name The name of the Docker image.
#' @param version The version of the Docker image. Defaults to "latest".
#'
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
