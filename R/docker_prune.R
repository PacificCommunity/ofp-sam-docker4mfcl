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
