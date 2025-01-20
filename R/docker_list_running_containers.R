#' List running Docker containers
#'
#' This function lists all currently running Docker containers.
#'
#' @return A data frame containing container ID, image name, and container name for each running container.
#'
#' @examples
#' docker_list_running_containers()
#'
#' @export

docker_list_running_containers <- function() {
  command <- "docker ps --format '{{.ID}} {{.Image}} {{.Names}}'"
  result <- system(command, intern = TRUE)
  if (length(result) == 0) {
    cat("No running containers found.\n")
    return(data.frame(ID = character(), Image = character(), Name = character(), stringsAsFactors = FALSE))
  }
  cat("Running containers:\n", paste(result, collapse = "\n"), "\n")

  # Parse the result into a data frame
  containers <- do.call(rbind, strsplit(result, " "))
  return(data.frame(ID = containers[, 1], Image = containers[, 2], Name = containers[, 3], stringsAsFactors = FALSE))
}
