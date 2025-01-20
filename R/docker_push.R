#' Push a Docker image to Docker Hub
#'
#' This function pushes a Docker image to Docker Hub
#'
#' @param local_image The name of the local Docker image.
#' @param remote_image The name of the remote Docker image.
#' @param username The Docker Hub username.
#' @param tag The tag of the Docker image. Defaults to "latest".
#'
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
