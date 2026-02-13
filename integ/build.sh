#!/bin/bash
set -ex

# Default values
AWS_ACCOUNT=""
AWS_REGION=""
VALIDATOR_REPOSITORY="amazon/aws-for-fluent-bit-validator"
VALIDATOR_TYPE=""
TAG=""
# Create a unique temporary builder name
MULTI_BUILDER="aws-flb-temp-builder-$(date +%s)"

# Function to display usage information
usage() {
  echo "Usage: $0 [OPTIONS]"
  echo "Build and push multiplatform Docker images for S3 or CloudWatch validation."
  echo ""
  echo "Options:"
  echo "  -h, --help                 Display this help message"
  echo "  -a, --account ACCOUNT      AWS account ID"
  echo "  -r, --region REGION        AWS region (e.g., us-west-2)"
  echo "  -n, --name REPOSITORY      Repository name (default: amazon/aws-for-fluent-bit-validator)"
  echo "  -t, --tag TAG              Specify the image tag (default: based on validator type)"
  echo "  -v, --validator TYPE       Validator type: s3 or cloudwatch (required)"
  echo ""
  echo "Examples:"
  echo "  $0 --account 123456789012 --region us-west-2 --validator s3"
  echo "  $0 -a 123456789012 -r us-west-2 -v cloudwatch -t v1.0.0"
  echo "  $0 -a 123456789012 -r us-west-2 -v s3 -n custom/repository-name"
  exit 1
}

# Function to parse command line arguments
parse_args() {
  while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
      -h|--help)
        usage
        ;;
      -a|--account)
        AWS_ACCOUNT="$2"
        shift 2
        ;;
      -r|--region)
        AWS_REGION="$2"
        shift 2
        ;;
      -n|--name)
        VALIDATOR_REPOSITORY="$2"
        shift 2
        ;;
      -t|--tag)
        TAG="$2"
        shift 2
        ;;
      -v|--validator)
        VALIDATOR_TYPE="$2"
        shift 2
        ;;
      *)
        echo "Unknown option: $1"
        usage
        ;;
    esac
  done
}

# Function to handle errors
error_exit() {
  echo "ERROR: $1" >&2
  exit 1
}

# Function to log information
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Function to validate arguments and set validator-specific values
validate_args() {
  # Check required parameters
  [[ -z "${AWS_ACCOUNT}" ]] && error_exit "AWS account ID is required. Use -a or --account to specify it."
  [[ -z "${AWS_REGION}" ]] && error_exit "AWS region is required. Use -r or --region to specify it."
  [[ -z "${VALIDATOR_TYPE}" ]] && error_exit "Validator type is required. Use -v or --validator to specify it."
  
  # Set validator-specific values based on validator type
  if [[ "${VALIDATOR_TYPE}" == "s3" ]]; then
    VALIDATOR_PREFIX="s3-integ-validator"
    VALIDATOR_DIR="s3"
    EXPORT_VAR="S3_INTEG_VALIDATOR_IMAGE"
  elif [[ "${VALIDATOR_TYPE}" == "cloudwatch" ]]; then
    VALIDATOR_PREFIX="cw-integ-validator"
    VALIDATOR_DIR="validate_cloudwatch"
    EXPORT_VAR="CW_INTEG_VALIDATOR_IMAGE"
  else
    error_exit "Validator type must be specified as 's3' or 'cloudwatch'"
  fi
  
  # Set default tag if not provided
  if [[ -z "${TAG}" ]]; then
    TAG="${VALIDATOR_PREFIX}-latest"
  fi
  
  # VALIDATOR_REPOSITORY has a default value, so this check is just for extra safety
  [[ -z "${VALIDATOR_REPOSITORY}" ]] && error_exit "Repository name is empty. This shouldn't happen as it has a default value."
  
  # Construct the full repository URL
  ECR_REPOSITORY="${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com"
  FULL_REPOSITORY_URL="${ECR_REPOSITORY}/${VALIDATOR_REPOSITORY}"
  log "Using repository: ${FULL_REPOSITORY_URL}"
  log "Using tag: ${TAG}"
  log "Validator type: ${VALIDATOR_TYPE}"
}

# Function to apply public access policy to repository
apply_public_policy() {
  local repo_name="$1"
  
  log "Applying public access policy to repository ${repo_name}..."
  
  # Create a temporary policy file
  local policy_file=$(mktemp)
  cat > "${policy_file}" << 'EOF'
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Sid": "Public",
      "Effect": "Allow",
      "Principal": "*",
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:BatchGetImage",
        "ecr:DescribeImages",
        "ecr:DescribeRepositories",
        "ecr:GetDownloadUrlForLayer",
        "ecr:ListImages"
      ]
    }
  ]
}
EOF
  
  # Apply the policy
  if ! aws ecr set-repository-policy --repository-name "${repo_name}" --policy-text file://"${policy_file}" --region "${AWS_REGION}"; then
    rm "${policy_file}"
    error_exit "Failed to apply public access policy to repository ${repo_name}"
  fi
  
  # Clean up
  rm "${policy_file}"
  log "Public access policy applied successfully to repository ${repo_name}."
}

# Function to check if repository exists and create it if needed
check_and_create_repository() {
  local repo_name="$1"
  
  log "Checking if repository ${repo_name} exists..."
  if ! aws ecr describe-repositories --repository-names "${repo_name}" --region "${AWS_REGION}" > /dev/null 2>&1; then
    log "Repository ${repo_name} does not exist. Creating it automatically..."
    if ! aws ecr create-repository --repository-name "${repo_name}" --region "${AWS_REGION}"; then
      error_exit "Failed to create repository ${repo_name}"
    fi
    log "Repository ${repo_name} created successfully."
    
    # Always apply public policy to newly created repositories
    apply_public_policy "${repo_name}"
  else
    log "Repository ${repo_name} exists."
  fi
}

# Function to setup repository and login
setup_repository() {
  # Check if repository exists and create it if needed
  check_and_create_repository "${VALIDATOR_REPOSITORY}"
  
  # Verify Docker buildx is available
  if ! docker buildx version > /dev/null 2>&1; then
    error_exit "Docker buildx is not available. Please install or enable Docker buildx."
  fi
  
  # Login to ECR
  log "Logging in to ECR..."
  if ! aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REPOSITORY}; then
    error_exit "Failed to login to ECR"
  fi
  
  # Remove existing images before building
  remove_existing_images
}

# Function to remove existing images from the repository manifest
remove_existing_images() {
  log "Checking for existing images in the repository..."
  
  # Check if the image with the specified tag exists in the repository
  if aws ecr describe-images --repository-name ${VALIDATOR_REPOSITORY} --image-ids imageTag=${TAG} --region ${AWS_REGION} &> /dev/null; then
    log "Found existing image with tag ${TAG} in repository."
    
    # Get the image digests from the manifest list
    log "Retrieving image digests from manifest list..."
    IMAGE_DIGESTS=$(aws ecr batch-get-image --repository-name ${VALIDATOR_REPOSITORY} --image-ids imageTag=${TAG} --region ${AWS_REGION} --output text --query 'images[].imageManifest' | jq '.manifests[].digest' | tr -d '"')
    
    # Delete the manifest list by tag
    log "Removing manifest list by tag..."
    if ! aws ecr batch-delete-image --repository-name ${VALIDATOR_REPOSITORY} --image-ids imageTag=${TAG} --region ${AWS_REGION}; then
      log "Warning: Failed to delete manifest list with tag ${TAG} from repository"
    else
      log "Successfully removed manifest list with tag ${TAG} from repository"
    fi
    
    # Delete all images using their digests in a single command
    if [[ -n "${IMAGE_DIGESTS}" ]]; then
      log "Found image digests, deleting all images in a single command..."
      
      # Build the image-ids parameter with all digests
      DELETE_ARGS=""
      for digest in ${IMAGE_DIGESTS}; do
        DELETE_ARGS="${DELETE_ARGS} imageDigest=${digest}"
      done
      
      log "Removing images with digests: ${IMAGE_DIGESTS}"
      if ! aws ecr batch-delete-image --repository-name ${VALIDATOR_REPOSITORY} --image-ids ${DELETE_ARGS} --region ${AWS_REGION}; then
        log "Warning: Failed to delete images with digests from repository"
      else
        log "Successfully removed images with digests from repository"
      fi
    else
      log "Warning: Could not find image digests in manifest list"
    fi
  else
    log "No existing image with tag ${TAG} found in repository"
  fi
  
  log "Image cleanup completed"
}

# Function to build and push the image
build_and_push_image() {
  # Change to the validator directory
  log "Changing to validator directory: ${VALIDATOR_DIR}"
  cd "$(dirname "$0")/${VALIDATOR_DIR}" || error_exit "Failed to change to validator directory: ${VALIDATOR_DIR}"
  
  # Build and push multi-architecture image directly
  log "Building and pushing multi-architecture image..."
  export DOCKER_CLI_EXPERIMENTAL=enabled
  
  log "Creating new buildx builder instance with multi-platform support: ${MULTI_BUILDER}"
  if ! docker buildx create --name ${MULTI_BUILDER} --use --platform linux/amd64,linux/arm64; then
    error_exit "Failed to create buildx builder with multi-platform support"
  fi
  
  log "Building and pushing multi-architecture image directly..."
  if ! docker buildx build --platform linux/amd64,linux/arm64 \
    -t ${FULL_REPOSITORY_URL}:${TAG} \
    --provenance=false \
    --push .; then
    error_exit "Failed to build and push multi-architecture image"
  fi
}

# Function to verify the image and output results
verify_and_output() {
  log "Verifying image..."
  if ! aws ecr describe-images --repository-name ${VALIDATOR_REPOSITORY} --image-ids imageTag=${TAG} --region ${AWS_REGION} > /dev/null 2>&1; then
    log "Warning: Could not verify image ${FULL_REPOSITORY_URL}:${TAG} in ECR"
  else
    log "Successfully verified image ${FULL_REPOSITORY_URL}:${TAG} in ECR"
  fi
  
  log "Build process completed successfully"
  
  # Output the export command for the validator image
  echo ""
  echo "Set the following environment variable to use this image:"
  echo "export ${EXPORT_VAR}=${FULL_REPOSITORY_URL}:${TAG}"
}

# Main function to orchestrate the workflow
main() {
  log "Starting multiplatform image build process"
  
  # Parse command line arguments
  parse_args "$@"
  
  # Validate arguments and set validator-specific values
  validate_args
  
  # Setup repository and login
  setup_repository
  
  # Build and push the image
  build_and_push_image
  
  # Verify the image and output results
  verify_and_output
}

# Setup cleanup function
cleanup() {
  log "Cleaning up resources..."
  if docker buildx inspect ${MULTI_BUILDER} &> /dev/null; then
    log "Removing buildx builder: ${MULTI_BUILDER}"
    docker buildx rm ${MULTI_BUILDER}
  fi
}

# Set trap for cleanup on exit
trap cleanup EXIT

# Execute the main function with all script arguments
main "$@"
