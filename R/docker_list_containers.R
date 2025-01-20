#' List Docker containers
#'
#' This function lists all available Docker containers. Optionally, it can include stopped containers.
#'
#' @param all Logical. If TRUE, includes stopped containers. Defaults to FALSE.
#'
#' @return A character vector of Docker container names and their associated images.
#'
#' @examples
#' docker_list_containers()
#' docker_list_containers(all = TRUE)
#'
#' @export

docker_list_containers <- function(all = FALSE) {
  flag <- if (all) "-a" else ""
  command <- sprintf("docker ps %s --format '{{.Names}} ({{.Image}})'", flag)
  result <- system(command, intern = TRUE)
  cat("Available Docker containers:\n", paste(result, collapse = "\n"), "\n")
  return(result)
}
