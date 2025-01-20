#' Remove a Docker image
#'
#' This function removes a Docker image with the specified name and version if it exists.
#'
#' @param image_name The name of the Docker image.
#' @param version The version of the Docker image. Defaults to "latest".
#'
#' @examples
#' docker_remove("my_image", "1.0")
#'
#' @export

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
