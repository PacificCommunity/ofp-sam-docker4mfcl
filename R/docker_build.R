#' Build a Docker image
#'
#' This function builds a Docker image with the specified name and version.
#'
#' @param image_name The name of the Docker image. Defaults to "default_image".
#' @param version The version of the Docker image. Defaults to "latest".
#' @param build_context The build context for the Docker image. Defaults to the current directory.
#'
#' @examples
#' docker_build(image_name = "my_image", version = "1.0")
#'
#' @export

docker_build <- function(image_name = "default_image", version = "latest", build_context = ".") {
  # Combine image name and version
  full_image_name <- sprintf("%s:%s", image_name, version)

  # Build Docker image with version
  command <- sprintf("docker build -t %s %s", full_image_name, build_context)
  cat("Running command:", command, "\n")
  system(command)
}
