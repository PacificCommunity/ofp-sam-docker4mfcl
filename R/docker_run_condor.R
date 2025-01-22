#' Run MFCL Job via HTCondor and Docker with Separate Clone and Run Scripts
#'
#' This function creates two Bash script files. The first script, \code{clone_job.sh},
#' handles cloning a GitHub repository (or a specific folder via sparse checkout) using the provided
#' GitHub Personal Access Token (PAT). The second script, \code{run_job.sh}, sources the clone script
#' to perform the clone, stores the working directory in a variable, schedules the deletion of the clone
#' script (to remove sensitive PAT information from disk), and then executes the remaining commands
#' (running \code{make} and archiving the appropriate folder). An HTCondor submit file is also generated
#' and transferred to a remote server for job submission.
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
#' @return No return value; side effects include the creation and transfer of script files to the remote server
#'   and submission of an HTCondor job.
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
  # Define file names for the two scripts.
  clone_script <- "clone_job.sh"
  run_script <- "run_job.sh"
  
  # 1. Create the clone_job.sh script.
  cat(sprintf("
#!/bin/bash

# Set GitHub environment variables (for cloning only)
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
", 
              github_pat, github_username, github_org, github_repo,
              if (!is.null(target_folder)) sprintf("export GITHUB_TARGET_FOLDER='%s'", target_folder) else ""
  ),
  file = clone_script)
  
  # 2. Create the run_job.sh script.
  # This script sources the clone script, saves the working directory in WORK_DIR,
  # schedules deletion of the clone script (with a delay) to remove the PAT from disk,
  # and then continues with make and archiving.
  cat(sprintf("
#!/bin/bash

# Source the clone script to perform the git clone.
source %s

# Restrict permissions to prevent others from opening or reading the script.
chmod 000 clone_job.sh

# Save the working directory to WORK_DIR so subsequent commands can use it.
if [[ -n \"$GITHUB_TARGET_FOLDER\" ]]; then
    WORK_DIR=\"$GITHUB_TARGET_FOLDER\"
else
    WORK_DIR=\"$GITHUB_REPO\"
fi

# Schedule deletion of the clone script in the background (wait 1 second before deleting).
( sleep 1; rm -f \"$(realpath %s)\" ) &

# Unset the GitHub PAT.
unset GITHUB_PAT

# Change into the working directory and run make.
cd \"$WORK_DIR\" || exit 1
echo \"Running make...\"
make

# Go back to the parent directory.
cd ..
echo \"Archiving folder: $WORK_DIR...\"
tar -czvf output_archive.tar.gz \"$WORK_DIR\"

# Optionally, delete the clone_job.sh script for cleanup.
rm -f clone_job.sh

", 
              clone_script, clone_script),
      file = run_script)
  
  # 3. Create the HTCondor submit file content.
  condor_options <- c()
  if (!is.null(condor_cpus)) {
    condor_options <- c(condor_options, sprintf("request_cpus = %s", condor_cpus))
  }
  if (!is.null(condor_memory)) {
    condor_options <- c(condor_options, sprintf("request_memory = %s", condor_memory))
  }
  condor_options <- paste(condor_options, collapse = "\n")
  
  submit_file <- "condor_job.submit"
  cat(sprintf("
Universe   = docker
DockerImage = %s
Executable = /bin/bash
Arguments  = %s
ShouldTransferFiles = YES
TransferInputFiles = %s, %s
TransferOutputFiles = output_archive.tar.gz
Output     = condor_job.out
Error      = condor_job.err
Log        = condor_job.log
%s
Queue
", 
              docker_image, run_script, clone_script, run_script, condor_options),
      file = submit_file)
  
  # 4. Check if the remote directory exists; if not, create it.
  message("Checking if the remote directory exists...")
  system(sprintf("ssh %s@%s 'mkdir -p %s'", remote_user, remote_host, remote_dir))
  
  # 5. Transfer the Bash scripts and submit file to the remote server.
  message("Transferring the Bash scripts and submit file to the remote server...")
  system(sprintf("scp %s %s@%s:%s/%s", clone_script, remote_user, remote_host, remote_dir, clone_script))
  system(sprintf("scp %s %s@%s:%s/%s", run_script, remote_user, remote_host, remote_dir, run_script))
  system(sprintf("scp %s %s@%s:%s/%s", submit_file, remote_user, remote_host, remote_dir, submit_file))
  
  # 6. Submit the Condor job on the remote server.
  message("Submitting the Condor job on the remote server...")
  system(sprintf("ssh %s@%s 'cd %s && condor_submit %s'", remote_user, remote_host, remote_dir, submit_file))
  
  # 7. Clean up local files.
  unlink(c(clone_script, run_script, submit_file))
  
  message("Condor job submitted successfully!")
}
