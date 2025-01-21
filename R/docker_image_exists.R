#' Check if a Docker image exists
#'
#' This function checks whether a Docker image with the specified name and version exists.
#'
#' @param image_name The name of the Docker image.
#' @param version The version of the Docker image. Defaults to "latest".
#'
#' @return TRUE if the image exists, FALSE otherwise.
#'
#' @examples
#' docker_image_exists("my_image", "1.0")
#'
#' @export

docker_image_exists <- function(image_name, version = "latest") {
  full_image_name <- sprintf("%s:%s", image_name, version)
  images <- docker_list_images()
  return(full_image_name %in% images)
}
