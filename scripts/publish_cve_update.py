#!/usr/bin/env python3

from datetime import datetime
import subprocess
import os

# Check if this is an automated or manual execution
automated = os.getenv("FLUENT_BIT_CVE_AUTOMATION")
automated = int(automated) > 0

git_cli_path = '/usr/bin/git'

def run_command(command_arr, timeout=None, tries=1, cwd=None, fail_on_error=False, env=None):
    i = 0
    output = None
    for i in range(tries):
        try:
            output = subprocess.run(command_arr,
                                    stdout=subprocess.PIPE,
                                    timeout=timeout,
                                    cwd=cwd,
                                    env=env).stdout.decode('utf-8')
        except subprocess.TimeoutExpired as ex:
            print(f"Command {command_arr} timed out after {ex.timeout} seconds.")
            print(f"Partial output (stdout): {ex.stdout}")
            print(f"Partial output (stderr): {ex.stderr}")
        except Exception as ex:
            print(f"Command {command_arr} had unexpected exception {ex}")

        # Return output if the command succeeded
        if output is not None:
            return output

    # Failure handling
    print(f"Failed to run command {command_arr}")
    if fail_on_error:
        print("Quitting...")
        quit()


is_new_al_version = run_command(["./scripts/check_for_new_al_version.sh"], timeout=10, tries=3, fail_on_error=True)
new_al2_version = None
if is_new_al_version == 'false':
    print("Amazon Linux version is up to date.")
    quit()
else:
    print("New Amazon Linux version is available.")
    new_al2_version = run_command(["./scripts/most_recent_al2.sh"], timeout=10, tries=3, fail_on_error=True)
    print("New AL2 version: {}".format(new_al2_version))

# Get upstream_to_fluent_bit
max_clone_attempts = 3
upstream_repo = "/tmp/fluent-bit/"
upstream_uri = "https://github.com/amazon-contributing/upstream-to-fluent-bit.git"
for i in range(max_clone_attempts):

    run_command(["rm", "-rf", upstream_repo])
    run_command(["mkdir", upstream_repo])
    clone_output = run_command(["git", "clone", upstream_uri, upstream_repo],
                               fail_on_error=False, timeout=30)
    if clone_output is not None:
        run_command(["git", "checkout", "1.9.10"], cwd=upstream_repo,
                    fail_on_error=True)
        break
else:
    print("Couldn't clone FLB upstream. Will ignore upstream commits.")
    upstream_repo = None

# Go to a new branch for this automation.
numeric_date_string = datetime.now().strftime("%Y%m%d")
branch_name = "patch-automation-{}".format(numeric_date_string)
run_command([git_cli_path, "fetch".format(numeric_date_string)],
            fail_on_error=True, tries=2)
run_command([git_cli_path, "switch", "-C", branch_name],
            fail_on_error=True)
current_branch = run_command(["git", "rev-parse", "--abbrev-ref", "HEAD"],
                             fail_on_error=True)
current_branch = current_branch.strip()
if current_branch != branch_name:
    print("failed to switch branch to {}".format(branch_name))
    print("current branch: {}".format(current_branch))
    quit()
# Reset the branch to master in case it isn't already
run_command([git_cli_path, "reset", "--hard", "mainline"])

# Derive the new version number
old_version = run_command(["cat", "AWS_FOR_FLUENT_BIT_VERSION"], fail_on_error=True)
semantic_version_components = old_version.split('.')
version_num_count = len(semantic_version_components)
if version_num_count == 3:
    semantic_version_components = semantic_version_components + [numeric_date_string]
elif version_num_count == 4:
    semantic_version_components[3] = numeric_date_string
else:
    print("Invalid semantic versioning for current version. Aborting...")
    quit()

new_version = ".".join(semantic_version_components)

# Update version file
with open("AWS_FOR_FLUENT_BIT_VERSION", "w") as version_file:
    version_file.write(new_version)

# Update linux.version file
with open("linux.version", 'r') as version_file:
    linux_version = version_file.readlines()

old_version = "{}".format(old_version)
print("old aws-for-fluent-bit version number: {}".format(old_version))
print("new aws-for-fluent-bit version number: {}".format(new_version))
for linum in range(len(linux_version)):
    # print("linux.version line: {}".format(linux_version[linum]))
    if old_version in linux_version[linum]:
        linux_version[linum] = linux_version[linum].replace(old_version, new_version)
        break
else:
    print("could not auto-locate version number in linux.version!!!")
    print("Guessing at line to modify based on file format...")
    linux_version[2] = '    "version": "{}",\n'.format(new_version)

with open("linux.version", 'w') as version_file:
    version_file.writelines(linux_version)

# Update changelog
run_command(["./scripts/generate_changelog.sh"],
            # Provide fluent bit directory to the changelog script,
            # if we were able to clone it.
            env={"FLUENT_BIT_DIRECTORY": upstream_repo} if upstream_repo is not None else None,
            timeout=20, tries=3,
            fail_on_error=True)

# Commit changes
run_command(["git", "commit", "-a", "--message", '"Release {}"'.format(new_version)],
            fail_on_error=True)

# Push changes to remote.
# Might fail if there are unexpected commits, but we ignore that as expected
core_push_command = ["git", "push"]
if automated:
    core_push_command = core_push_command + ["--force"]
push_output = run_command(core_push_command,
                          fail_on_error=False)
if push_output is None or push_output == "" or ("fatal: The current branch" in push_output and "has no upstream branch" in push_output):
    # Sometimes you need to set the pustream if it doesn't exist
    print("push may have failed due to missing set-upstream. Retrying")
    push_output = run_command(core_push_command + ["--set-upstream", "origin", branch_name],
                              fail_on_error=False)

# Go back to mainline
run_command(["git", "checkout", "mainline"], timeout=30)
