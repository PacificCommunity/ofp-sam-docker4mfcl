% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/docker_push.R
\name{docker_push}
\alias{docker_push}
\title{Push a Docker image to Docker Hub}
\usage{
docker_push(local_image, remote_image, username, tag = "latest")
}
\arguments{
\item{local_image}{The name of the local Docker image.}

\item{remote_image}{The name of the remote Docker image.}

\item{username}{The Docker Hub username.}

\item{tag}{The tag of the Docker image. Defaults to "latest".}
}
\description{
This function pushes a Docker image to Docker Hub
}
\examples{
docker_push("my_image", "my_image", "my_username", "1.0")

}
