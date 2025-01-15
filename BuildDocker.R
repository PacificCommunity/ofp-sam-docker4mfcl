source("tools/MakeDocker.R")

# Example usage
create_dockerfile(
  r_version = "4.3.0",
  r_packages = c("ggplot2", "dplyr", "tidyverse", "remotes"),
  github_packages = c("rstudio/shiny", "tidyverse/dplyr"),
  base_image = "ubuntu:22.04",
  image_name = "my_r_image"
)
