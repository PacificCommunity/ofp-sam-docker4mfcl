#' Run MFCL Job via HTCondor and Docker
#'
#' This function clones a GitHub repository (or a specific folder using sparse checkout),
#' runs the \code{make} command, archives the specified folder (or the entire repository if no
#' folder is specified) into a tar.gz file, and then creates and submits an HTCondor job on a
#' remote server using Docker. The function transfers the generated Bash script and Condor
#' submit file to the remote server before job submission.
#'
#' @param remote_user Character. Remote server username.
#' @param remote_host Character. Remote server address.
#' @param remote_dir Character. Remote working directory.
#' @param github_pat Character. GitHub Personal Access Token.
#' @param github_username Character. GitHub username.
#' @param github_org Character. GitHub organisation name.
#' @param github_repo Character. GitHub repository name.
#' @param docker_image Character. Docker image to use.
#' @param target_folder Character, optional. Specific folder within the repository to clone (via sparse checkout)
#'   and where \code{make} is executed. If not provided, the entire repository is used.
#' @param condor_cpus Numeric, optional. The number of CPUs to request in the HTCondor job.
#' @param condor_memory Character, optional. The amount of memory to request (e.g., "4GB") in the HTCondor job.
#'
#' @return No return value; side effects include transfer of files to the remote server and job submission.
#'
#' @details
#' The function performs the following steps:
#'
#' \enumerate{
#'   \item Creates a fixed Bash script file (\code{run_job.sh}) that:
#'     \itemizes{
#'       \item Sets GitHub-related environment variables.
#'       \item Clones the entire repository. If \code{target_folder} is specified, performs a sparse checkout.
#'       \item Immediately deletes the script file to remove any PAT assignment from disk.
#'       \item Changes into the appropriate directory and runs \code{make}.
#'       \item Archives the chosen folder into \code{output_archive.tar.gz} (archives \code{target_folder} if specified, else archives the entire repository).
#'       \item Unsets the PAT environment variable.
#'     }
#'   \item Creates an HTCondor submit file (\code{condor_job.submit}) that specifies the use of Docker, the executable,
#'         file transfers, and optionally resource requests such as CPUs and memory.
#'   \item Checks for the remote directory's existence (creating it if necessary) and then transfers the generated
#'         script and submit file to the remote server.
#'   \item Submits the Condor job on the remote server.
#' }
#'
#' @examples
#' \dontrun{
#'   docker_run_condor(
#'     remote_user = "myuser",
#'     remote_host = "remote.server.com",
#'     remote_dir  = "/home/myuser/jobs",
#'     github_pat = "ghp_xxxxxxxxxxxxxxxxxxxx",
#'     github_username = "mygithub",
#'     github_org = "myorg",
#'     github_repo = "myrepo",
#'     docker_image = "mydocker/image:latest",
#'     target_folder = "src",
#'     condor_cpus = 4,
#'     condor_memory = "4GB"
#'   )
#' }
#'
#' @export
docker_run_condor <- function(
    remote_user,      # Remote server username.
    remote_host,      # Remote server address.
    remote_dir,       # Remote working directory.
    github_pat,       # GitHub Personal Access Token.
    github_username,  # GitHub username.
    github_org,       # GitHub organisation name.
    github_repo,      # GitHub repository name.
    docker_image,     # Docker image to use.
    target_folder = NULL,  # Optional: specific folder within the repository.
    condor_cpus = NULL,    # Optional: number of CPUs to request.
    condor_memory = NULL   # Optional: memory to request (e.g., "4GB").
) {
  # 1. Fixed file name for the Bash script.
  bash_script <- "run_job.sh"  # Fixed name for the Bash script.
  
  # Create the Bash script content.
  # 주의: self-deletion(자기 삭제)를 위해, git clone 이후에 스크립트 파일 자체를 삭제합니다.
  # "\"\\$0\""는 실제 Bash 스크립트에서는 "$0"로 기록됩니다.
  cat(sprintf("
#!/bin/bash

# Set environment variables
export GITHUB_PAT='%s'
export GITHUB_USERNAME='%s'
export GITHUB_ORGANIZATION='%s'
export GITHUB_REPO='%s'
%s

# Clone the repository or, if GITHUB_TARGET_FOLDER is set, perform a sparse checkout.
if [[ -n \"$GITHUB_TARGET_FOLDER\" ]]; then
    echo \"Cloning specific folder ($GITHUB_TARGET_FOLDER) from the repository...\"
    git init
    git remote add origin https://$GITHUB_USERNAME:$GITHUB_PAT@github.com/$GITHUB_ORGANIZATION/$GITHUB_REPO.git
    git config core.sparseCheckout true
    echo \"$GITHUB_TARGET_FOLDER/\" >> .git/info/sparse-checkout
    git pull origin main
else
    echo \"Cloning the entire repository...\"
    git clone https://$GITHUB_USERNAME:$GITHUB_PAT@github.com/$GITHUB_ORGANIZATION/$GITHUB_REPO.git
fi

# Immediately delete this script file to remove the PAT from disk
rm -- \"\\$0\"
unset GITHUB_PAT

# Change into the appropriate directory and run make
if [[ -n \"$GITHUB_TARGET_FOLDER\" ]]; then
    cd \"$GITHUB_TARGET_FOLDER\" || exit 1
else
    cd \"$GITHUB_REPO\" || exit 1
fi
echo \"Running make...\"
make

# Go back to the parent directory
cd ..

# Determine which folder to archive: if a target folder is specified, archive it; otherwise archive the entire repository.
if [[ -n \"$GITHUB_TARGET_FOLDER\" ]]; then
    archive_folder=\"$GITHUB_TARGET_FOLDER\"
else
    archive_folder=\"$GITHUB_REPO\"
fi

echo \"Archiving folder: $archive_folder...\"
tar -czvf output_archive.tar.gz \"$archive_folder\"

# Clean up sensitive information
unset GITHUB_PAT
", 
              github_pat, github_username, github_org, github_repo,
              if (!is.null(target_folder)) sprintf("export GITHUB_TARGET_FOLDER='%s'", target_folder) else ""
  ), 
  file = bash_script)
  
  # 2. Create the HTCondor submit file content.
  # Build additional Condor options for CPU and memory requests if specified.
  condor_options <- c()
  if (!is.null(condor_cpus)) {
    condor_options <- c(condor_options, sprintf("request_cpus = %s", condor_cpus))
  }
  if (!is.null(condor_memory)) {
    condor_options <- c(condor_options, sprintf("request_memory = %s", condor_memory))
  }
  condor_options <- paste(condor_options, collapse = "\n")
  
  submit_file <- "condor_job.submit"  # Fixed name for the submit file.
  cat(sprintf("
Universe   = docker
DockerImage = %s
Executable = /bin/bash
Arguments  = run_job.sh
ShouldTransferFiles = YES
TransferInputFiles = run_job.sh
TransferOutputFiles = output_archive.tar.gz
Output     = condor_job.out
Error      = condor_job.err
Log        = condor_job.log
%s
Queue
", docker_image, condor_options), file = submit_file)
  
  # 3. Check if the remote directory exists; if not, create it.
  message("Checking if the remote directory exists...")
  system(sprintf("ssh %s@%s 'mkdir -p %s'", remote_user, remote_host, remote_dir))
  
  # 4. Transfer the Bash script and submit file to the remote server.
  message("Transferring the Bash script and submit file to the remote server...")
  system(sprintf("scp %s %s@%s:%s/%s", bash_script, remote_user, remote_host, remote_dir, bash_script))
  system(sprintf("scp %s %s@%s:%s/%s", submit_file, remote_user, remote_host, remote_dir, submit_file))
  
  # 5. Submit the Condor job on the remote server.
  message("Submitting the Condor job on the remote server...")
  system(sprintf("ssh %s@%s 'cd %s && condor_submit %s'", remote_user, remote_host, remote_dir, submit_file))
  
  # 6. Clean up local files.
  unlink(c(bash_script, submit_file))
  
  message("Condor job submitted successfully!")
}
