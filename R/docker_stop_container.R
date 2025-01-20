#' Stop a Docker container
#'
#' This function stops a specific Docker container by its ID or name.
#'
#' @param container_id_or_name The ID or name of the container to stop.
#'
#' @examples
#' docker_stop_container("my_container")
#'
#' @export

docker_stop_container <- function(container_id_or_name) {
  command <- sprintf("docker stop %s", container_id_or_name)
  cat("Stopping container:", container_id_or_name, "\n")
  system(command)
}
