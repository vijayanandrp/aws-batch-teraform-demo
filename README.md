## Manual steps
1. Adding User - Roles/Policies for get necessary permissions
2. S3 Demo bucket creation Example - `s3-encrypt-demo-batch`
3. Samples files push to S3 bucket. `Crypto_file_Services.bash` `symmetric_keyfile.key`

## Deployment Steps:

We cannot use **AWS Cloudshell** to run terraform script. 
Rather, We can run it either locally or launch an **AWS EC2**  instance to run this.

### 01 - Pre-request inside EC2 Instance (AWS Linux 2) ec2-user

```bash
cd ~
# Install Packages
sudo amazon-linux-extras install epel -y
sudo yum install yum-utils  -y
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
sudo yum install terraform  -y
sudo amazon-linux-extras install docker -y
sudo yum install git -y

# start docker ec2
sudo service docker start
sudo usermod -a -G docker ec2-user

#start docker cloudshell
sudo systemctl enable docker
sudo systemctl start docker
sudo dockerd
sudo usermod -a -G docker cloudshell-user

# debug
docker info

# install awscli
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
./aws/install -i /usr/local/aws-cli -b /usr/local/bin

# This token from a USER ROLE should have neccessary actions to create docker and upload ECR 
# AWS Access Key ID [None]: 
# AWS Secret Access Key [None]
aws configure
aws s3 ls
```

## 02 - Terraform Steps with Sudo SU permissions 

Step_01: `terraform init`

Step_02: `terraform plan`

Step_03: `terraform apply --auto-approve` To create the stack

Step_04:`terraform destroy --auto-approve` To destroy the stack




### How to create a symmetric key file? 
`openssl rand 256 > symmetric_keyfile.key`
**NOTE**: Upload to S3  Demo Bucket

Also upload the `crytpo_file_service.bash` to same bucket

### How to use pigz?

`$ pigz -9 -k -p4 LinuxShellTipsBackup.iso`

The command options:
```
-9: Provides the best compression (High compression).
-k: Retains the original file.
-p4: Tells Pigz to use 4 processor cores since it’s multi-core oriented.
More processor cores make the compression process faster. 
The number of processor cores you choose to use should depend on the processor properties of your machine 
e.g. Core i3, Core i5, Core i7.
```

### AWS Lambda Trigger 
```python
def lambda_handler(event, context):
    print("Hello from app1!")
    
    response = client.submit_job(
    jobDefinition='batch-ex-fargate:2',
    jobName='demo_lambda_batch_3',
    jobQueue='HighPriorityFargate',
    shareIdentifier='A1*',
    schedulingPriorityOverride=0,
    containerOverrides={
        'command': ["file_crypto_service.bash", "60"],
        'environment': [
            {
                'name': 'BATCH_FILE_S3_URL',
                'value': 's3://s3-encrypt-demo-batch/file_crypto_service.bash'
            },
            {
                'name': 'BATCH_FILE_TYPE',
                'value': 'script'
            },
            {
                'name': 'ENV_SOURCE_BUCKET',
                'value': 's3-encrypt-demo-batch'
            },
            {
                'name': 'ENV_TARGET_BUCKET',
                'value': 's3-encrypt-demo-batch'
            },
            {
                'name': 'ENV_FILE_KEY',
                'value': 'testData.csv'
            },
            {
                'name': 'ENV_IS_ENCRYPT',
                'value': 'true'
            },
            {
                'name': 'ENV_CLEAN_TEMP',
                'value': 'true'
            },
            {
                'name': 'ENV_SYMMETRIC_KEY',
                'value': 's3://s3-encrypt-demo-batch/symmetric_keyfile.key'
            }
        ]
        },
       timeout={
        'attemptDurationSeconds': 3000
    },
    )

    print(response)
```


#### Reference:  
https://aws.amazon.com/blogs/compute/creating-a-simple-fetch-and-run-aws-batch-job/

## Usage
https://boto3.amazonaws.com/v1/documentation/api/latest/reference/services/batch.html#Batch.Client.submit_job

See [`examples`](https://github.com/terraform-aws-modules/terraform-aws-batch/tree/master/examples) directory for working examples to reference:

```hcl
module "batch" {
  source = "terraform-aws-modules/batch/aws"

  compute_environments = {
    a_ec2 = {
      name_prefix = "ec2"

      compute_resources = {
        type           = "EC2"
        min_vcpus      = 4
        max_vcpus      = 16
        desired_vcpus  = 4
        instance_types = ["m5.large", "r5.large"]

        security_group_ids = ["sg-f1d03a88"]
        subnets            = ["subnet-30ef7b3c", "subnet-1ecda77b", "subnet-ca09ddbc"]

        # Note - any tag changes here will force compute environment replacement
        # which can lead to job queue conflicts. Only specify tags that will be static
        # for the lifetime of the compute environment
        tags = {
          # This will set the name on the Ec2 instances launched by this compute environment
          Name = "example"
          Type = "Ec2"
        }
      }
    }

    b_ec2_spot = {
      name_prefix = "ec2_spot"

      compute_resources = {
        type                = "SPOT"
        allocation_strategy = "SPOT_CAPACITY_OPTIMIZED"
        bid_percentage      = 20

        min_vcpus      = 4
        max_vcpus      = 16
        desired_vcpus  = 4
        instance_types = ["m4.large", "m3.large", "r4.large", "r3.large"]

        security_group_ids = ["sg-f1d03a88"]
        subnets            = ["subnet-30ef7b3c", "subnet-1ecda77b", "subnet-ca09ddbc"]

        # Note - any tag changes here will force compute environment replacement
        # which can lead to job queue conflicts. Only specify tags that will be static
        # for the lifetime of the compute environment
        tags = {
          # This will set the name on the Ec2 instances launched by this compute environment
          Name = "example-spot"
          Type = "Ec2Spot"
        }
      }
    }
  }

  # Job queus and scheduling policies
  job_queues = {
    low_priority = {
      name     = "LowPriorityEc2"
      state    = "ENABLED"
      priority = 1

      tags = {
        JobQueue = "Low priority job queue"
      }
    }

    high_priority = {
      name     = "HighPriorityEc2"
      state    = "ENABLED"
      priority = 99

      fair_share_policy = {
        compute_reservation = 1
        share_decay_seconds = 3600

        share_distribution = [{
          share_identifier = "A1*"
          weight_factor    = 0.1
          }, {
          share_identifier = "A2"
          weight_factor    = 0.2
        }]
      }

      tags = {
        JobQueue = "High priority job queue"
      }
    }
  }

  job_definitions = {
    example = {
      name           = "example"
      propagate_tags = true

      container_properties = jsonencode({
        command = ["ls", "-la"]
        image   = "public.ecr.aws/runecast/busybox:1.33.1"
        resourceRequirements = [
          { type = "VCPU", value = "1" },
          { type = "MEMORY", value = "1024" }
        ]
        logConfiguration = {
          logDriver = "awslogs"
          options = {
            awslogs-group         = "/aws/batch/example"
            awslogs-region        = "us-east-1"
            awslogs-stream-prefix = "ec2"
          }
        }
      })

      attempt_duration_seconds = 60
      retry_strategy = {
        attempts = 3
        evaluate_on_exit = {
          retry_error = {
            action       = "RETRY"
            on_exit_code = 1
          }
          exit_success = {
            action       = "EXIT"
            on_exit_code = 0
          }
        }
      }

      tags = {
        JobDefinition = "Example"
      }
    }
  }

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}
```

## Examples

Examples codified under the [`examples`](https://github.com/terraform-aws-modules/terraform-aws-batch/tree/master/examples) are intended to give users references for how to use the module(s) as well as testing/validating changes to the source code of the module. If contributing to the project, please be sure to make any appropriate updates to the relevant examples to allow maintainers to test your changes and to keep the examples up to date for users. Thank you!

- [EC2](https://github.com/terraform-aws-modules/terraform-aws-batch/tree/master/examples/ec2)
- [Fargate](https://github.com/terraform-aws-modules/terraform-aws-batch/tree/master/examples/fargate)

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 0.13.1 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 3.30 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 3.30 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_batch_compute_environment.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/batch_compute_environment) | resource |
| [aws_batch_job_definition.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/batch_job_definition) | resource |
| [aws_batch_job_queue.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/batch_job_queue) | resource |
| [aws_batch_scheduling_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/batch_scheduling_policy) | resource |
| [aws_iam_instance_profile.instance](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_role.instance](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.spot_fleet](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.instance](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.spot_fleet](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_policy_document.instance](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.spot_fleet](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_compute_environments"></a> [compute\_environments](#input\_compute\_environments) | Map of compute environment definitions to create | `any` | `{}` | no |
| <a name="input_create"></a> [create](#input\_create) | Controls if resources should be created (affects nearly all resources) | `bool` | `true` | no |
| <a name="input_create_instance_iam_role"></a> [create\_instance\_iam\_role](#input\_create\_instance\_iam\_role) | Determines whether a an IAM role is created or to use an existing IAM role | `bool` | `true` | no |
| <a name="input_create_job_definitions"></a> [create\_job\_definitions](#input\_create\_job\_definitions) | Determines whether to create the job definitions defined | `bool` | `true` | no |
| <a name="input_create_job_queues"></a> [create\_job\_queues](#input\_create\_job\_queues) | Determines whether to create job queues | `bool` | `true` | no |
| <a name="input_create_service_iam_role"></a> [create\_service\_iam\_role](#input\_create\_service\_iam\_role) | Determines whether a an IAM role is created or to use an existing IAM role | `bool` | `true` | no |
| <a name="input_create_spot_fleet_iam_role"></a> [create\_spot\_fleet\_iam\_role](#input\_create\_spot\_fleet\_iam\_role) | Determines whether a an IAM role is created or to use an existing IAM role | `bool` | `false` | no |
| <a name="input_instance_iam_role_additional_policies"></a> [instance\_iam\_role\_additional\_policies](#input\_instance\_iam\_role\_additional\_policies) | Additional policies to be added to the IAM role | `list(string)` | `[]` | no |
| <a name="input_instance_iam_role_description"></a> [instance\_iam\_role\_description](#input\_instance\_iam\_role\_description) | Cluster instance IAM role description | `string` | `null` | no |
| <a name="input_instance_iam_role_name"></a> [instance\_iam\_role\_name](#input\_instance\_iam\_role\_name) | Cluster instance IAM role name | `string` | `null` | no |
| <a name="input_instance_iam_role_path"></a> [instance\_iam\_role\_path](#input\_instance\_iam\_role\_path) | Cluster instance IAM role path | `string` | `null` | no |
| <a name="input_instance_iam_role_permissions_boundary"></a> [instance\_iam\_role\_permissions\_boundary](#input\_instance\_iam\_role\_permissions\_boundary) | ARN of the policy that is used to set the permissions boundary for the IAM role | `string` | `null` | no |
| <a name="input_instance_iam_role_tags"></a> [instance\_iam\_role\_tags](#input\_instance\_iam\_role\_tags) | A map of additional tags to add to the IAM role created | `map(string)` | `{}` | no |
| <a name="input_instance_iam_role_use_name_prefix"></a> [instance\_iam\_role\_use\_name\_prefix](#input\_instance\_iam\_role\_use\_name\_prefix) | Determines whether the IAM role name (`instance_iam_role_name`) is used as a prefix | `string` | `true` | no |
| <a name="input_job_definitions"></a> [job\_definitions](#input\_job\_definitions) | Map of job definitions to create | `any` | `{}` | no |
| <a name="input_job_queues"></a> [job\_queues](#input\_job\_queues) | Map of job queue and scheduling policy defintions to create | `any` | `{}` | no |
| <a name="input_service_iam_role_additional_policies"></a> [service\_iam\_role\_additional\_policies](#input\_service\_iam\_role\_additional\_policies) | Additional policies to be added to the IAM role | `list(string)` | `[]` | no |
| <a name="input_service_iam_role_description"></a> [service\_iam\_role\_description](#input\_service\_iam\_role\_description) | Batch service IAM role description | `string` | `null` | no |
| <a name="input_service_iam_role_name"></a> [service\_iam\_role\_name](#input\_service\_iam\_role\_name) | Batch service IAM role name | `string` | `null` | no |
| <a name="input_service_iam_role_path"></a> [service\_iam\_role\_path](#input\_service\_iam\_role\_path) | Batch service IAM role path | `string` | `null` | no |
| <a name="input_service_iam_role_permissions_boundary"></a> [service\_iam\_role\_permissions\_boundary](#input\_service\_iam\_role\_permissions\_boundary) | ARN of the policy that is used to set the permissions boundary for the IAM role | `string` | `null` | no |
| <a name="input_service_iam_role_tags"></a> [service\_iam\_role\_tags](#input\_service\_iam\_role\_tags) | A map of additional tags to add to the IAM role created | `map(string)` | `{}` | no |
| <a name="input_service_iam_role_use_name_prefix"></a> [service\_iam\_role\_use\_name\_prefix](#input\_service\_iam\_role\_use\_name\_prefix) | Determines whether the IAM role name (`service_iam_role_name`) is used as a prefix | `string` | `true` | no |
| <a name="input_spot_fleet_iam_role_additional_policies"></a> [spot\_fleet\_iam\_role\_additional\_policies](#input\_spot\_fleet\_iam\_role\_additional\_policies) | Additional policies to be added to the IAM role | `list(string)` | `[]` | no |
| <a name="input_spot_fleet_iam_role_description"></a> [spot\_fleet\_iam\_role\_description](#input\_spot\_fleet\_iam\_role\_description) | Spot fleet IAM role description | `string` | `null` | no |
| <a name="input_spot_fleet_iam_role_name"></a> [spot\_fleet\_iam\_role\_name](#input\_spot\_fleet\_iam\_role\_name) | Spot fleet IAM role name | `string` | `null` | no |
| <a name="input_spot_fleet_iam_role_path"></a> [spot\_fleet\_iam\_role\_path](#input\_spot\_fleet\_iam\_role\_path) | Spot fleet IAM role path | `string` | `null` | no |
| <a name="input_spot_fleet_iam_role_permissions_boundary"></a> [spot\_fleet\_iam\_role\_permissions\_boundary](#input\_spot\_fleet\_iam\_role\_permissions\_boundary) | ARN of the policy that is used to set the permissions boundary for the IAM role | `string` | `null` | no |
| <a name="input_spot_fleet_iam_role_tags"></a> [spot\_fleet\_iam\_role\_tags](#input\_spot\_fleet\_iam\_role\_tags) | A map of additional tags to add to the IAM role created | `map(string)` | `{}` | no |
| <a name="input_spot_fleet_iam_role_use_name_prefix"></a> [spot\_fleet\_iam\_role\_use\_name\_prefix](#input\_spot\_fleet\_iam\_role\_use\_name\_prefix) | Determines whether the IAM role name (`spot_fleet_iam_role_name`) is used as a prefix | `string` | `true` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to add to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_compute_environments"></a> [compute\_environments](#output\_compute\_environments) | Map of compute environments created and their associated attributes |
| <a name="output_instance_iam_instance_profile_arn"></a> [instance\_iam\_instance\_profile\_arn](#output\_instance\_iam\_instance\_profile\_arn) | ARN assigned by AWS to the instance profile |
| <a name="output_instance_iam_instance_profile_id"></a> [instance\_iam\_instance\_profile\_id](#output\_instance\_iam\_instance\_profile\_id) | Instance profile's ID |
| <a name="output_instance_iam_instance_profile_unique"></a> [instance\_iam\_instance\_profile\_unique](#output\_instance\_iam\_instance\_profile\_unique) | Stable and unique string identifying the IAM instance profile |
| <a name="output_instance_iam_role_arn"></a> [instance\_iam\_role\_arn](#output\_instance\_iam\_role\_arn) | The Amazon Resource Name (ARN) specifying the IAM role |
| <a name="output_instance_iam_role_name"></a> [instance\_iam\_role\_name](#output\_instance\_iam\_role\_name) | The name of the IAM role |
| <a name="output_instance_iam_role_unique_id"></a> [instance\_iam\_role\_unique\_id](#output\_instance\_iam\_role\_unique\_id) | Stable and unique string identifying the IAM role |
| <a name="output_job_definitions"></a> [job\_definitions](#output\_job\_definitions) | Map of job defintions created and their associated attributes |
| <a name="output_job_queues"></a> [job\_queues](#output\_job\_queues) | Map of job queues created and their associated attributes |
| <a name="output_scheduling_policies"></a> [scheduling\_policies](#output\_scheduling\_policies) | Map of scheduling policies created and their associated attributes |
| <a name="output_service_iam_role_arn"></a> [service\_iam\_role\_arn](#output\_service\_iam\_role\_arn) | The Amazon Resource Name (ARN) specifying the IAM role |
| <a name="output_service_iam_role_name"></a> [service\_iam\_role\_name](#output\_service\_iam\_role\_name) | The name of the IAM role |
| <a name="output_service_iam_role_unique_id"></a> [service\_iam\_role\_unique\_id](#output\_service\_iam\_role\_unique\_id) | Stable and unique string identifying the IAM role |
| <a name="output_spot_fleet_iam_role_arn"></a> [spot\_fleet\_iam\_role\_arn](#output\_spot\_fleet\_iam\_role\_arn) | The Amazon Resource Name (ARN) specifying the IAM role |
| <a name="output_spot_fleet_iam_role_name"></a> [spot\_fleet\_iam\_role\_name](#output\_spot\_fleet\_iam\_role\_name) | The name of the IAM role |
| <a name="output_spot_fleet_iam_role_unique_id"></a> [spot\_fleet\_iam\_role\_unique\_id](#output\_spot\_fleet\_iam\_role\_unique\_id) | Stable and unique string identifying the IAM role |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->

## License

Apache-2.0 Licensed. See [LICENSE](https://github.com/terraform-aws-modules/terraform-aws-batch/blob/master/LICENSE).
