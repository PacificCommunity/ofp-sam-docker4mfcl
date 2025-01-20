#' List Docker images
#'
#' This function lists all available Docker images.
#'
#' @return A character vector of Docker images in the format "repository:tag".
#'
#' @examples
#' docker_list_images()

docker_list_images <- function() {
  command <- "docker images --format '{{.Repository}}:{{.Tag}}'"
  result <- system(command, intern = TRUE)
  cat("Available Docker images:\n", paste(result, collapse = "\n"), "\n")
  return(result)
}
