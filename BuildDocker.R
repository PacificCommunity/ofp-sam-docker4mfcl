source("tools/GenerateDockerfile.R")
source("tools/DockerFunctions.R")


docker_list_images()
docker_list_containers()

# Example usage
create_dockerfile(
  r_version = "4.2.3",
  base_image = "ubuntu:22.04"
)

docker_build(image_name = "skj", version = "22")
docker_remove(image_name = "custom_r_image")

docker_prune()

docker_run_mfcl(
  image_name = "skj:22", 
  command = c("./mfclo64 skj_base.frq 09.par 09_new.par -switch 1 1 1 1",
              "./mfclo64 skj_base2.frq 09.par 09_new.par -switch 1 1 1 1"),
  sub_dir = c("test_mfcl", "test_mfcl2"),
  parallel = T
  #project_dir = "/home/user/my_r_project"
)
