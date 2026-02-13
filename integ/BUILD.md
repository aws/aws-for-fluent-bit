# Validator Build Guide

This document provides instructions for building and publishing validator Docker images using the unified `build.sh` script. The script builds multiplatform images for both `linux/amd64` and `linux/arm64` architectures and publishes them to Amazon ECR.

## Supported Validators

The script supports building the following validator types:
- **S3 Validator**: For validating S3 integration tests
- **CloudWatch Validator**: For validating CloudWatch integration tests

## Prerequisites

### AWS CLI

Ensure you have the AWS CLI installed and configured with appropriate permissions to:
- Create and manage ECR repositories
- Push images to ECR
- Apply repository policies

### Docker Buildx

The script uses Docker Buildx for multiplatform builds. Ensure you have Docker installed with Buildx support:

```bash
# Check if buildx is available
docker buildx version
```

### QEMU for Architecture Emulation

To build images for different architectures on a single host, you need QEMU:

```bash
# Install QEMU support for multiplatform builds
docker run --privileged --rm tonistiigi/binfmt --install all
```

This command installs the necessary QEMU emulators to build images for different architectures.

### Container Image Store

For multiplatform builds, you need:

1. **Containerd Image Store**: This is the recommended approach for better performance. See [Docker's containerd documentation](https://docs.docker.com/engine/storage/containerd/) for instructions on enabling this feature in `/etc/docker/daemon.json`.

2. **Temporary Builder Instance**: The script defines a unique builder name at initialization and automatically creates a temporary builder instance. This builder is automatically cleaned up when the script exits, ensuring no orphaned builders are left behind:
```bash
# Define a unique temporary builder name
MULTI_BUILDER="aws-flb-temp-builder-$(date +%s)"

# Later in the build process:
docker buildx create --name ${MULTI_BUILDER} --use --platform linux/amd64,linux/arm64
```

3. **Automatic Cleanup**: The script uses a trap handler to ensure the builder is removed on exit:
```bash
trap cleanup EXIT
```
This ensures proper resource cleanup even if the script exits unexpectedly.

> **Note**: The script handles the builder instance creation automatically. This is just for reference to understand what's happening behind the scenes.

## Usage

### Basic Usage

```bash
./build.sh -a <AWS_ACCOUNT_ID> -r <AWS_REGION> -v <VALIDATOR_TYPE>
```

Where `<VALIDATOR_TYPE>` is either `s3` or `cloudwatch`.

### Command-Line Options

```
Usage: ./build.sh [OPTIONS]
Build and push multiplatform Docker images for S3 or CloudWatch validation.

Options:
  -h, --help                 Display this help message
  -a, --account ACCOUNT      AWS account ID
  -r, --region REGION        AWS region (e.g., us-west-2)
  -n, --name REPOSITORY      Repository name (default: amazon/aws-for-fluent-bit-validator)
  -t, --tag TAG              Specify the image tag (default: based on validator type)
  -v, --validator TYPE       Validator type: s3 or cloudwatch (required)
```

### Examples

1. Build S3 validator with default repository and tag:
```bash
./build.sh -a 123456789012 -r us-west-2 -v s3
```

2. Build CloudWatch validator with default repository and tag:
```bash
./build.sh -a 123456789012 -r us-west-2 -v cloudwatch
```

3. Build S3 validator with a custom tag:
```bash
./build.sh -a 123456789012 -r us-west-2 -v s3 -t v1.0.0
```

4. Build CloudWatch validator with a custom repository name:
```bash
./build.sh -a 123456789012 -r us-west-2 -v cloudwatch -n custom/repository-name
```

## Script Structure

The `build.sh` script follows a modular design with clearly defined functions for better maintainability and readability:

### Key Functions

- **parse_args()**: Processes command-line arguments and sets corresponding variables
- **validate_args()**: Validates required parameters and sets validator-specific values based on the validator type
- **setup_repository()**: Checks if the repository exists, creates it if needed, applies policies, and logs in to ECR
- **build_and_push_image()**: Changes to the validator directory and executes the Docker buildx commands
- **verify_and_output()**: Verifies the image was pushed successfully and outputs the environment variable to use
- **main()**: Orchestrates the workflow by calling the above functions in sequence

This modular approach makes the script easier to maintain and extend in the future.

## Repository Management

The script checks if the specified ECR repository exists. If it doesn't, it automatically creates it without prompting. When a new repository is created, the script automatically applies a public access policy that allows any AWS account to pull images from the repository.

### Public Access Policy

The following policy is applied to newly created repositories:

```json
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
```

## Image Cleanup Process

Before building new images, the script automatically cleans up any existing images with the same tag in the ECR repository. The cleanup process follows these steps:

1. **Check for Existing Images**: The script checks if an image with the specified tag exists in the repository.

2. **Retrieve Image Digests**: If an image exists, the script retrieves all image digests from the manifest list:
   ```bash
   aws ecr batch-get-image --repository-name ${REPOSITORY} --image-ids imageTag=${TAG} --output text --query 'images[].imageManifest' | jq '.manifests[].digest'
   ```

3. **Delete Manifest List**: The script removes the manifest list by tag:
   ```bash
   aws ecr batch-delete-image --repository-name ${REPOSITORY} --image-ids imageTag=${TAG}
   ```

4. **Delete Individual Images**: The script then deletes all images referenced by the manifest list in a single batch operation:
   ```bash
   aws ecr batch-delete-image --repository-name ${REPOSITORY} --image-ids imageDigest=${DIGEST1} imageDigest=${DIGEST2} ...
   ```

This cleanup process ensures that no stale images remain in the repository before pushing new ones, preventing potential conflicts and ensuring a clean deployment.

## Multiplatform Build Process

The build process uses a direct multi-architecture build approach:

1. **Create Temporary Multi-Platform Builder**: The script creates a temporary builder instance with multi-platform support and a unique name.
2. **Build and Push**: A single command builds and pushes the multi-architecture image directly to ECR:
   ```bash
   docker buildx build --platform linux/amd64,linux/arm64 -t ${REPOSITORY_URL}:${TAG} --push .
   ```
3. **Verify**: The script verifies that the multi-architecture image was successfully pushed to ECR.

This approach is more efficient because:
- It avoids pushing intermediate images
- It handles all the complexity of multi-architecture builds internally within Docker buildx
- It eliminates potential issues with manifest list creation and reference digests

## Environment Variables

After successful execution, the script outputs an export command for setting the appropriate environment variable:

- For S3 validator:
  ```bash
  export S3_INTEG_VALIDATOR_IMAGE=${REPOSITORY_URL}:${TAG}
  ```

- For CloudWatch validator:
  ```bash
  export CW_INTEG_VALIDATOR_IMAGE=${REPOSITORY_URL}:${TAG}
  ```

These environment variables can be used in integration tests to reference the built validator images.

## Troubleshooting

### Common Issues

1. **QEMU Not Installed**:
```
Error: failed to solve: process "/bin/sh -c ..." did not complete successfully
```
Solution: Install QEMU emulators with `docker run --privileged --rm tonistiigi/binfmt --install all`

2. **Docker Buildx Not Available**:
```
ERROR: Docker buildx is not available. Please install or enable Docker buildx.
```
Solution: Ensure Docker is updated to a version that supports Buildx.

3. **ECR Authentication Failure**:
```
ERROR: Failed to login to ECR
```
Solution: Verify your AWS credentials and ensure you have the necessary permissions.

4. **Manifest List Errors**:
```
failed to put manifest: manifest blob unknown: Images with digests [...] required for pushing image into repository [...] do not exist
```
Solution: This error should no longer occur with the updated build script, which uses a direct multi-architecture build approach. If you encounter this error, ensure you're using the latest version of the build script.

5. **Validator Directory Not Found**:
```
ERROR: Failed to change to validator directory
```
Solution: Ensure you're running the script from the `integ` directory or a directory that has the correct relative path to the validator directories.

### Additional Resources

For more information on multiplatform Docker builds, refer to:
- [Docker Documentation: Multi-platform builds](https://docs.docker.com/build/building/multi-platform/)
- [AWS ECR Documentation](https://docs.aws.amazon.com/AmazonECR/latest/userguide/what-is-ecr.html)
