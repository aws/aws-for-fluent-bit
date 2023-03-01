package main

import (
	"bytes"
	"fmt"
	"io"
	"io/ioutil"
	"net/http"
	"net/url"
	"os"
	"testing"

	"github.com/aws/aws-sdk-go/service/s3"
	"github.com/aws/aws-sdk-go/service/s3/s3manager"
	"github.com/stretchr/testify/assert"
)

const s3FileDirectoryPathTest = "fluent-bit-init-s3-files/"
const metadataResponse = (`{"Cluster":"ecs-cluster","TaskARN":"arn:aws:ecs:us-west-2:123456789123:task/ecs-cluster/4ca5a280e68947cd84a8357f0d008fb5","Family":"code_test_A","Revision":"35","DesiredStatus":"RUNNING","KnownStatus":"RUNNING","PullStartedAt":"2022-07-06T03:06:45.282195951Z","PullStoppedAt":"2022-07-06T03:06:47.089531338Z","AvailabilityZone":"us-west-2a","LaunchType":"EC2","Containers":[{"DockerId":"8c928beb55e3989caf270cee85835e7f199715ffe44e6d54f5aeb68bf79a275c","Name":"log_router","DockerName":"ecs-code_test_A-35-logrouter-fea8e8aecab7ceeacc01","Image":"123456789123.dkr.ecr.us-west-2.amazonaws.com/x_image:latest","ImageID":"sha256:bfdcbace4206be5e917ae71648bbb680d8ddc1cf558e60b8aad1e9e5533233a0","Labels":{"com.amazonaws.ecs.cluster":"ecs-cluster","com.amazonaws.ecs.container-name":"log_router","com.amazonaws.ecs.task-arn":"arn:aws:ecs:us-west-2:123456789123:task/ecs-cluster/4ca5a280e68947cd84a8357f0d008fb5","com.amazonaws.ecs.task-definition-family":"code_test_A","com.amazonaws.ecs.task-definition-version":"35"},"DesiredStatus":"RUNNING","KnownStatus":"RUNNING","Limits":{"CPU":2,"Memory":0},"CreatedAt":"2022-07-06T03:06:45.425156017Z","StartedAt":"2022-07-06T03:06:46.070292719Z","Type":"NORMAL","Volumes":[{"Source":"/var/lib/ecs/deps/execute-command/bin/3.1.1260.0/ssm-session-worker","Destination":"/ecs-execute-command-6de6aecd-5468-4666-9ad9-b1521a24893c/ssm-session-worker"},{"Source":"/var/lib/ecs/deps/execute-command/config/amazon-ssm-agent-ZfC4ex5qAj4jNHNZsam9TbekaQ_EkbnJMsW0hcZEbFI=.json","Destination":"/ecs-execute-command-6de6aecd-5468-4666-9ad9-b1521a24893c/configuration/amazon-ssm-agent.json"},{"Source":"/var/lib/ecs/deps/execute-command/config/seelog-gEZ-TIvHAyOLfMC5wiWRofgDMlDzaCZ6zcswnAoop84=.xml","Destination":"/ecs-execute-command-6de6aecd-5468-4666-9ad9-b1521a24893c/configuration/seelog.xml"},{"Source":"/var/lib/ecs/deps/execute-command/certs/tls-ca-bundle.pem","Destination":"/ecs-execute-command-6de6aecd-5468-4666-9ad9-b1521a24893c/certs/amazon-ssm-agent.crt"},{"Source":"/var/lib/ecs/data/firelens/4ca5a280e68947cd84a8357f0d008fb5/socket","Destination":"/var/run"},{"Source":"/var/lib/ecs/deps/execute-command/bin/3.1.1260.0/amazon-ssm-agent","Destination":"/ecs-execute-command-6de6aecd-5468-4666-9ad9-b1521a24893c/amazon-ssm-agent"},{"Source":"/var/log/ecs/exec/4ca5a280e68947cd84a8357f0d008fb5/log_router","Destination":"/var/log/amazon/ssm"},{"Source":"/var/lib/ecs/data/firelens/4ca5a280e68947cd84a8357f0d008fb5/config/fluent.conf","Destination":"/fluent-bit/etc/fluent-bit.conf"},{"Source":"/var/lib/ecs/deps/execute-command/bin/3.1.1260.0/ssm-agent-worker","Destination":"/ecs-execute-command-6de6aecd-5468-4666-9ad9-b1521a24893c/ssm-agent-worker"}],"LogDriver":"awslogs","LogOptions":{"awslogs-create-group":"true","awslogs-group":"/ecs/code_test_A","awslogs-region":"us-west-2","awslogs-stream":"ecs/log_router/4ca5a280e68947cd84a8357f0d008fb5"},"ContainerARN":"arn:aws:ecs:us-west-2:123456789123:container/ecs-cluster/4ca5a280e68947cd84a8357f0d008fb5/cf2297e2-6204-4132-9d7b-6c1cab4c4f8e","Networks":[{"NetworkMode":"bridge","IPv4Addresses":["172.17.0.2"]}]},{"DockerId":"f2eb74ec6624e8f0ed4763f3c1b5dd6da6fc7810d4df83245fe419f28d34cbf4","Name":"app","DockerName":"ecs-code_test_A-35-app-beacfe98d8fabbc01400","Image":"nginx:latest","ImageID":"sha256:55f4b40fe486a5b734b46bb7bf28f52fa31426bf23be068c8e7b19e58d9b8deb","Labels":{"com.amazonaws.ecs.cluster":"ecs-cluster","com.amazonaws.ecs.container-name":"app","com.amazonaws.ecs.task-arn":"arn:aws:ecs:us-west-2:123456789123:task/ecs-cluster/4ca5a280e68947cd84a8357f0d008fb5","com.amazonaws.ecs.task-definition-family":"code_test_A","com.amazonaws.ecs.task-definition-version":"35"},"DesiredStatus":"RUNNING","KnownStatus":"RUNNING","Limits":{"CPU":2,"Memory":0},"CreatedAt":"2022-07-06T03:06:47.103306928Z","StartedAt":"2022-07-06T03:06:47.757888246Z","Type":"NORMAL","Volumes":[{"Source":"/var/lib/ecs/deps/execute-command/config/seelog-gEZ-TIvHAyOLfMC5wiWRofgDMlDzaCZ6zcswnAoop84=.xml","Destination":"/ecs-execute-command-64f2d8e8-ca2d-443b-b9b1-1410aee62888/configuration/seelog.xml"},{"Source":"/var/lib/ecs/deps/execute-command/certs/tls-ca-bundle.pem","Destination":"/ecs-execute-command-64f2d8e8-ca2d-443b-b9b1-1410aee62888/certs/amazon-ssm-agent.crt"},{"Source":"/var/log/ecs/exec/4ca5a280e68947cd84a8357f0d008fb5/app","Destination":"/var/log/amazon/ssm"},{"Source":"/var/lib/ecs/deps/execute-command/bin/3.1.1260.0/amazon-ssm-agent","Destination":"/ecs-execute-command-64f2d8e8-ca2d-443b-b9b1-1410aee62888/amazon-ssm-agent"},{"Source":"/var/lib/ecs/deps/execute-command/bin/3.1.1260.0/ssm-agent-worker","Destination":"/ecs-execute-command-64f2d8e8-ca2d-443b-b9b1-1410aee62888/ssm-agent-worker"},{"Source":"/var/lib/ecs/deps/execute-command/bin/3.1.1260.0/ssm-session-worker","Destination":"/ecs-execute-command-64f2d8e8-ca2d-443b-b9b1-1410aee62888/ssm-session-worker"},{"Source":"/var/lib/ecs/deps/execute-command/config/amazon-ssm-agent-ZfC4ex5qAj4jNHNZsam9TbekaQ_EkbnJMsW0hcZEbFI=.json","Destination":"/ecs-execute-command-64f2d8e8-ca2d-443b-b9b1-1410aee62888/configuration/amazon-ssm-agent.json"}],"LogDriver":"awsfirelens","LogOptions":{"Name":"cloudwatch","auto_create_group":"true","log_group_name":"/aws/ecs/containerinsights/$(ecs_cluster)/app_user","log_stream_name":"$(ecs_task_id)","region":"us-west-2","retry_limit":"2"},"ContainerARN":"arn:aws:ecs:us-west-2:123456789123:container/ecs-cluster/4ca5a280e68947cd84a8357f0d008fb5/65feb143-c5a1-4bcf-b524-0953a02524bf","Networks":[{"NetworkMode":"bridge","IPv4Addresses":["172.17.0.3"]}]}]}`)
const metadataResponseNoLaunchType = (`{"Cluster":"ecs-cluster","TaskARN":"arn:aws:ecs:us-west-2:123456789123:task/ecs-cluster/4ca5a280e68947cd84a8357f0d008fb5","Family":"code_test_A","Revision":"35","DesiredStatus":"RUNNING","KnownStatus":"RUNNING","PullStartedAt":"2022-07-06T03:06:45.282195951Z","PullStoppedAt":"2022-07-06T03:06:47.089531338Z","AvailabilityZone":"us-west-2a","Containers":[{"DockerId":"8c928beb55e3989caf270cee85835e7f199715ffe44e6d54f5aeb68bf79a275c","Name":"log_router","DockerName":"ecs-code_test_A-35-logrouter-fea8e8aecab7ceeacc01","Image":"123456789123.dkr.ecr.us-west-2.amazonaws.com/x_image:latest","ImageID":"sha256:bfdcbace4206be5e917ae71648bbb680d8ddc1cf558e60b8aad1e9e5533233a0","Labels":{"com.amazonaws.ecs.cluster":"ecs-cluster","com.amazonaws.ecs.container-name":"log_router","com.amazonaws.ecs.task-arn":"arn:aws:ecs:us-west-2:123456789123:task/ecs-cluster/4ca5a280e68947cd84a8357f0d008fb5","com.amazonaws.ecs.task-definition-family":"code_test_A","com.amazonaws.ecs.task-definition-version":"35"},"DesiredStatus":"RUNNING","KnownStatus":"RUNNING","Limits":{"CPU":2,"Memory":0},"CreatedAt":"2022-07-06T03:06:45.425156017Z","StartedAt":"2022-07-06T03:06:46.070292719Z","Type":"NORMAL","Volumes":[{"Source":"/var/lib/ecs/deps/execute-command/bin/3.1.1260.0/ssm-session-worker","Destination":"/ecs-execute-command-6de6aecd-5468-4666-9ad9-b1521a24893c/ssm-session-worker"},{"Source":"/var/lib/ecs/deps/execute-command/config/amazon-ssm-agent-ZfC4ex5qAj4jNHNZsam9TbekaQ_EkbnJMsW0hcZEbFI=.json","Destination":"/ecs-execute-command-6de6aecd-5468-4666-9ad9-b1521a24893c/configuration/amazon-ssm-agent.json"},{"Source":"/var/lib/ecs/deps/execute-command/config/seelog-gEZ-TIvHAyOLfMC5wiWRofgDMlDzaCZ6zcswnAoop84=.xml","Destination":"/ecs-execute-command-6de6aecd-5468-4666-9ad9-b1521a24893c/configuration/seelog.xml"},{"Source":"/var/lib/ecs/deps/execute-command/certs/tls-ca-bundle.pem","Destination":"/ecs-execute-command-6de6aecd-5468-4666-9ad9-b1521a24893c/certs/amazon-ssm-agent.crt"},{"Source":"/var/lib/ecs/data/firelens/4ca5a280e68947cd84a8357f0d008fb5/socket","Destination":"/var/run"},{"Source":"/var/lib/ecs/deps/execute-command/bin/3.1.1260.0/amazon-ssm-agent","Destination":"/ecs-execute-command-6de6aecd-5468-4666-9ad9-b1521a24893c/amazon-ssm-agent"},{"Source":"/var/log/ecs/exec/4ca5a280e68947cd84a8357f0d008fb5/log_router","Destination":"/var/log/amazon/ssm"},{"Source":"/var/lib/ecs/data/firelens/4ca5a280e68947cd84a8357f0d008fb5/config/fluent.conf","Destination":"/fluent-bit/etc/fluent-bit.conf"},{"Source":"/var/lib/ecs/deps/execute-command/bin/3.1.1260.0/ssm-agent-worker","Destination":"/ecs-execute-command-6de6aecd-5468-4666-9ad9-b1521a24893c/ssm-agent-worker"}],"LogDriver":"awslogs","LogOptions":{"awslogs-create-group":"true","awslogs-group":"/ecs/code_test_A","awslogs-region":"us-west-2","awslogs-stream":"ecs/log_router/4ca5a280e68947cd84a8357f0d008fb5"},"ContainerARN":"arn:aws:ecs:us-west-2:123456789123:container/ecs-cluster/4ca5a280e68947cd84a8357f0d008fb5/cf2297e2-6204-4132-9d7b-6c1cab4c4f8e","Networks":[{"NetworkMode":"bridge","IPv4Addresses":["172.17.0.2"]}]},{"DockerId":"f2eb74ec6624e8f0ed4763f3c1b5dd6da6fc7810d4df83245fe419f28d34cbf4","Name":"app","DockerName":"ecs-code_test_A-35-app-beacfe98d8fabbc01400","Image":"nginx:latest","ImageID":"sha256:55f4b40fe486a5b734b46bb7bf28f52fa31426bf23be068c8e7b19e58d9b8deb","Labels":{"com.amazonaws.ecs.cluster":"ecs-cluster","com.amazonaws.ecs.container-name":"app","com.amazonaws.ecs.task-arn":"arn:aws:ecs:us-west-2:123456789123:task/ecs-cluster/4ca5a280e68947cd84a8357f0d008fb5","com.amazonaws.ecs.task-definition-family":"code_test_A","com.amazonaws.ecs.task-definition-version":"35"},"DesiredStatus":"RUNNING","KnownStatus":"RUNNING","Limits":{"CPU":2,"Memory":0},"CreatedAt":"2022-07-06T03:06:47.103306928Z","StartedAt":"2022-07-06T03:06:47.757888246Z","Type":"NORMAL","Volumes":[{"Source":"/var/lib/ecs/deps/execute-command/config/seelog-gEZ-TIvHAyOLfMC5wiWRofgDMlDzaCZ6zcswnAoop84=.xml","Destination":"/ecs-execute-command-64f2d8e8-ca2d-443b-b9b1-1410aee62888/configuration/seelog.xml"},{"Source":"/var/lib/ecs/deps/execute-command/certs/tls-ca-bundle.pem","Destination":"/ecs-execute-command-64f2d8e8-ca2d-443b-b9b1-1410aee62888/certs/amazon-ssm-agent.crt"},{"Source":"/var/log/ecs/exec/4ca5a280e68947cd84a8357f0d008fb5/app","Destination":"/var/log/amazon/ssm"},{"Source":"/var/lib/ecs/deps/execute-command/bin/3.1.1260.0/amazon-ssm-agent","Destination":"/ecs-execute-command-64f2d8e8-ca2d-443b-b9b1-1410aee62888/amazon-ssm-agent"},{"Source":"/var/lib/ecs/deps/execute-command/bin/3.1.1260.0/ssm-agent-worker","Destination":"/ecs-execute-command-64f2d8e8-ca2d-443b-b9b1-1410aee62888/ssm-agent-worker"},{"Source":"/var/lib/ecs/deps/execute-command/bin/3.1.1260.0/ssm-session-worker","Destination":"/ecs-execute-command-64f2d8e8-ca2d-443b-b9b1-1410aee62888/ssm-session-worker"},{"Source":"/var/lib/ecs/deps/execute-command/config/amazon-ssm-agent-ZfC4ex5qAj4jNHNZsam9TbekaQ_EkbnJMsW0hcZEbFI=.json","Destination":"/ecs-execute-command-64f2d8e8-ca2d-443b-b9b1-1410aee62888/configuration/amazon-ssm-agent.json"}],"LogDriver":"awsfirelens","LogOptions":{"Name":"cloudwatch","auto_create_group":"true","log_group_name":"/aws/ecs/containerinsights/$(ecs_cluster)/app_user","log_stream_name":"$(ecs_task_id)","region":"us-west-2","retry_limit":"2"},"ContainerARN":"arn:aws:ecs:us-west-2:123456789123:container/ecs-cluster/4ca5a280e68947cd84a8357f0d008fb5/65feb143-c5a1-4bcf-b524-0953a02524bf","Networks":[{"NetworkMode":"bridge","IPv4Addresses":["172.17.0.3"]}]}]}`)

func TestGetECSTaskMetadata(t *testing.T) {
	os.Setenv("ECS_CONTAINER_METADATA_URI_V4", "http://169.254.170.2/v4/50379854-baeb-4b84-9010-dd3fe2df5f20")

	// Test case 1: full metadata
	mockResponse1 := metadataResponse
	client1 := MockHTTPClient{
		Response: mockResponse1,
	}

	actualOutput1 := getECSTaskMetadata(&client1)

	expectedOutput1 := ECSTaskMetadata{
		AWS_REGION:            "us-west-2",
		AWS_AVAILABILITY_ZONE: "us-west-2a",
		ECS_CLUSTER:           "ecs-cluster",
		ECS_TASK_ARN:          "arn:aws:ecs:us-west-2:123456789123:task/ecs-cluster/4ca5a280e68947cd84a8357f0d008fb5",
		ECS_TASK_ID:           "4ca5a280e68947cd84a8357f0d008fb5",
		ECS_FAMILY:            "code_test_A",
		ECS_LAUNCH_TYPE:       "EC2",
		ECS_REVISION:          "35",
		ECS_TASK_DEFINITION:   "code_test_A:35",
	}

	assert.Equal(t, actualOutput1, expectedOutput1)

	// Test case 2: Task launch type will be an empty string if container agent is under version 1.45.0
	mockResponse2 := metadataResponseNoLaunchType
	client2 := MockHTTPClient{
		Response: mockResponse2,
	}

	actualOutput2 := getECSTaskMetadata(&client2)

	expectedOutput2 := ECSTaskMetadata{
		AWS_REGION:            "us-west-2",
		AWS_AVAILABILITY_ZONE: "us-west-2a",
		ECS_CLUSTER:           "ecs-cluster",
		ECS_TASK_ARN:          "arn:aws:ecs:us-west-2:123456789123:task/ecs-cluster/4ca5a280e68947cd84a8357f0d008fb5",
		ECS_TASK_ID:           "4ca5a280e68947cd84a8357f0d008fb5",
		ECS_FAMILY:            "code_test_A",
		ECS_LAUNCH_TYPE:       "", // empty lunch type
		ECS_REVISION:          "35",
		ECS_TASK_DEFINITION:   "code_test_A:35",
	}

	assert.Equal(t, actualOutput2, expectedOutput2)

	// Test case 3: run image locally without metadata
	os.Setenv("ECS_CONTAINER_METADATA_URI_V4", "")
	mockResponse3 := (``)
	client3 := MockHTTPClient{
		Response: mockResponse3,
	}

	actualOutput3 := getECSTaskMetadata(&client3)

	expectedOutput3 := ECSTaskMetadata{
		AWS_REGION:            "",
		AWS_AVAILABILITY_ZONE: "",
		ECS_CLUSTER:           "",
		ECS_TASK_ARN:          "",
		ECS_TASK_ID:           "",
		ECS_FAMILY:            "",
		ECS_LAUNCH_TYPE:       "",
		ECS_REVISION:          "",
		ECS_TASK_DEFINITION:   "",
	}

	assert.Equal(t, actualOutput3, expectedOutput3)
}

func TestSetECSTaskMetadata(t *testing.T) {

	var metadataList []ECSTaskMetadata
	var expectedContentList []string

	// Test case 1: full metadata
	metadataTest1 := ECSTaskMetadata{
		AWS_REGION:            "us-west-2",
		AWS_AVAILABILITY_ZONE: "us-west-2a",
		ECS_CLUSTER:           "ecs-Test",
		ECS_TASK_ARN:          "arn:aws:ecs:us-west-2:111:task/ecs-local-cluster/37e8",
		ECS_TASK_ID:           "56461",
		ECS_FAMILY:            "esc-task-definition",
		ECS_LAUNCH_TYPE:       "EC2",
		ECS_REVISION:          "1",
		ECS_TASK_DEFINITION:   "esc-task-definition:1",
	}

	expectedContent1 := "export FLB_AWS_USER_AGENT=ecs-init\n" +
		"export AWS_REGION=us-west-2\n" +
		"export AWS_AVAILABILITY_ZONE=us-west-2a\n" +
		"export ECS_CLUSTER=ecs-Test\n" +
		"export ECS_TASK_ARN=arn:aws:ecs:us-west-2:111:task/ecs-local-cluster/37e8\n" +
		"export ECS_TASK_ID=56461\n" +
		"export ECS_FAMILY=esc-task-definition\n" +
		"export ECS_LAUNCH_TYPE=EC2\n" +
		"export ECS_REVISION=1\n" +
		"export ECS_TASK_DEFINITION=esc-task-definition:1\n"

	metadataList = append(metadataList, metadataTest1)
	expectedContentList = append(expectedContentList, expectedContent1)

	// Test case 2: some environment variables is empty
	metadataTest2 := ECSTaskMetadata{
		AWS_REGION:            "us-west-1",
		AWS_AVAILABILITY_ZONE: "",
		ECS_CLUSTER:           "ecs-Test",
		ECS_TASK_ARN:          "",
		ECS_TASK_ID:           "",
		ECS_FAMILY:            "",
		ECS_LAUNCH_TYPE:       "",
		ECS_REVISION:          "",
		ECS_TASK_DEFINITION:   "",
	}

	expectedContent2 := "export FLB_AWS_USER_AGENT=ecs-init\n" +
		"export AWS_REGION=us-west-1\n" +
		"export ECS_CLUSTER=ecs-Test\n"

	metadataList = append(metadataList, metadataTest2)
	expectedContentList = append(expectedContentList, expectedContent2)

	//Add new test cases here if needed

	for i := 0; i < len(metadataList) && i < len(expectedContentList); i++ {
		testSetECSTaskMetadataHelper(t, &metadataList[i], &expectedContentList[i])
	}
}

func testSetECSTaskMetadataHelper(t *testing.T, metadata *ECSTaskMetadata, expectedContent *string) {
	filePath := "testSetECSMetadata.sh"
	file := createFileHelper(filePath)
	defer os.Remove(filePath)
	defer file.Close()

	setECSTaskMetadata(*metadata, filePath)

	actualContent := readFileHelper(filePath)
	assert.Equal(t, actualContent, *expectedContent)
}

func TestCreateCommand(t *testing.T) {
	expectedContent := baseCommand
	filePath := "fluent-bit-init.conf"
	createCommand(&baseCommand, filePath)
	expectedContent += " -c " + filePath

	assert.Equal(t, baseCommand, expectedContent)
}

func TestUpdateCommand(t *testing.T) {
	expectedContent := baseCommand

	// Test case 1
	parserFilePath1 := "/ecs/parser.conf"
	updateCommand(parserFilePath1)
	expectedContent += " -R " + parserFilePath1

	assert.Equal(t, baseCommand, expectedContent)

	// Test case 2
	parserFilePath2 := "/s3/parser2.conf"
	updateCommand(parserFilePath2)
	expectedContent += " -R " + parserFilePath2

	assert.Equal(t, baseCommand, expectedContent)
}

func TestWriteInclude(t *testing.T) {

	mainConfigFilePath := "mainFile.conf"
	file := createFileHelper(mainConfigFilePath)
	defer os.Remove(mainConfigFilePath)
	defer file.Close()

	var configFileList []string

	// Test file 1
	configFile1 := "testFile1.conf"
	configFileList = append(configFileList, configFile1)

	// Add test file 2
	configFile2 := "testFile2.conf"
	configFileList = append(configFileList, configFile2)

	// Add more config files here if needed

	var expectedContent string
	for i := 0; i < len(configFileList); i++ {
		writeInclude(configFileList[i], mainConfigFilePath)
		expectedContent += ("@INCLUDE " + configFileList[i] + "\n")
	}

	actualContent := readFileHelper(mainConfigFilePath)
	assert.Equal(t, actualContent, expectedContent)
}

func TestDownloadS3ConfigFile(t *testing.T) {

	defer os.RemoveAll(s3FileDirectoryPathTest)

	s3FilePath := "user/files/aaa.conf"
	bucketName := "userBucket"
	s3Downloader := MockS3Downloader{}

	downloadS3ConfigFile(&s3Downloader, s3FilePath, bucketName, s3FileDirectoryPathTest)

	actualContent := readFileHelper(s3FileDirectoryPathTest + "aaa.conf")
	expectedContent := "S3 config file download and store successfully"

	assert.Equal(t, actualContent, expectedContent)

}

func TestModifyInvokeFile(t *testing.T) {
	filePath := "testModifyInvoke.sh"
	file := createFileHelper(filePath)

	defer os.Remove(filePath)
	defer file.Close()

	expectedContent := baseCommand
	modifyInvokeFile(filePath)
	actualContent := readFileHelper(filePath)

	assert.Equal(t, actualContent, expectedContent)

}

type MockHTTPClient struct {
	Response string
}

func (mhc *MockHTTPClient) Get(str string) (*http.Response, error) {
	_, err := url.ParseRequestURI(str)
	if err != nil {
		return nil, fmt.Errorf("Invalid input for HTTP Client: %v", err)
	} else {
		body := ioutil.NopCloser(bytes.NewReader([]byte(mhc.Response)))
		return &http.Response{
			StatusCode: 200,
			Body:       body,
		}, nil
	}
}

type MockS3Downloader struct{}

func (msd *MockS3Downloader) Download(w io.WriterAt, input *s3.GetObjectInput, options ...func(*s3manager.Downloader)) (int64, error) {
	filePath := s3FileDirectoryPathTest + "aaa.conf"
	writeContent := "S3 config file download and store successfully"

	writeFileHelper(filePath, writeContent)

	return 100, nil
}

func createFileHelper(filePath string) *os.File {
	file, err := os.Create(filePath)
	if err != nil {
		fmt.Println("Failed to create the file to test")
	}

	return file
}

func readFileHelper(filePath string) string {
	content, err := ioutil.ReadFile(filePath)
	if err != nil {
		fmt.Errorf("failed to read the file: %s", filePath)
	}

	return string(content)
}

func writeFileHelper(filePath, writeContent string) {
	file := openFile(filePath)
	defer file.Close()

	_, err := file.WriteString(writeContent)
	if err != nil {
		fmt.Errorf("Can not write %s in file %s", writeContent, filePath)
	}
}
