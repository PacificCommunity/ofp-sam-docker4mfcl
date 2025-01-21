#' Stop unnecessary Docker containers
#'
#' This function stops all running Docker containers or filters by a specific image name.
#'
#' @param image_name The name of the Docker image to filter by. Defaults to NULL (all containers).
#'
#' @examples
#' docker_stop_unnecessary_containers()
#' docker_stop_unnecessary_containers(image_name = "my_image")
#'
#' @export

docker_stop_unnecessary_containers <- function(image_name = NULL) {
  containers <- docker_list_running_containers()

  if (nrow(containers) == 0) {
    cat("No containers to stop.\n")
    return()
  }

  # Filter containers by image name if provided
  if (!is.null(image_name)) {
    containers <- containers[containers$Image == image_name, ]
    if (nrow(containers) == 0) {
      cat("No containers found for image:", image_name, "\n")
      return()
    }
  }

  # Stop all matched containers
  for (container_id in containers$ID) {
    docker_stop_container(container_id)
  }
}
