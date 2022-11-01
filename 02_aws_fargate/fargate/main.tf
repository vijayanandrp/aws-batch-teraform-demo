provider "aws" {
  region = local.region
}

locals {
  region = "us-east-1"
  name   = "enc-dec-${replace(basename(path.cwd), "_", "-")}"
  owner = "etl"
  vpc_id = "vpc-0a1c11083c4812965"

  tags = {
    Owner        = local.owner
    Purpose      = local.owner
  }
}

data "aws_region" "current" {}

data "aws_subnets" "example" {
  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }
}

data "aws_subnet" "example" {
  for_each = toset(data.aws_subnets.example.ids)
  id       = each.value
}

output "subnet_cidr_blocks" {
  value = [for s in data.aws_subnet.example : s.cidr_block]
}

################################################################################
# Batch Module
################################################################################

module "batch_disabled" {
  source = "../../terraform/modules/terraform-aws-batch"

  create = false
}

module "batch" {
  source = "../../terraform/modules/terraform-aws-batch"

  instance_iam_role_name        = "${local.name}-ecs-instance-new"
  instance_iam_role_path        = "/batch/"
  instance_iam_role_description = "IAM instance role/profile for AWS Batch ECS instance(s)"
  instance_iam_role_tags = {
    ModuleCreatedRole = "Yes"
  }

  service_iam_role_name        = "${local.name}-batch-new"
  service_iam_role_path        = "/batch/"
  service_iam_role_description = "IAM service role for AWS Batch"
  service_iam_role_tags = {
    ModuleCreatedRole = "Yes"
  }

  create_spot_fleet_iam_role      = true
  spot_fleet_iam_role_name        = "${local.name}-spot-new"
  spot_fleet_iam_role_path        = "/batch/"
  spot_fleet_iam_role_description = "IAM spot fleet role for AWS Batch"
  spot_fleet_iam_role_tags = {
    ModuleCreatedRole = "Yes"
  }

  compute_environments = {
    a_fargate = {
      name_prefix = "fargate"

      compute_resources = {
        type      = "FARGATE"
        max_vcpus = 8

        security_group_ids = [module.vpc_efs_security_group.security_group_id, module.vpc_batch_security_group.security_group_id]
        subnets            =   "${slice(data.aws_subnets.example.ids, 0 , 16 )}"

        # `tags = {}` here is not applicable for spot
      }
    }

    b_fargate_spot = {
      name_prefix = "fargate_spot"

      compute_resources = {
        type      = "FARGATE_SPOT"
        max_vcpus = 8

        security_group_ids = [module.vpc_efs_security_group.security_group_id, module.vpc_batch_security_group.security_group_id]
        subnets            =  "${slice(data.aws_subnets.example.ids, 0 , 16 )}"

        # `tags = {}` here is not applicable for spot
      }
    }
  }

  # Job queus and scheduling policies
  job_queues = {
    low_priority = {
      name     = "LowPriorityFargate_2"
      state    = "ENABLED"
      priority = 1

      tags = {
        JobQueue     = "Low priority job queue"
        Owner        = local.owner
        Purpose      = local.owner
      }
    }

    high_priority = {
      name     = "HighPriorityFargate_2"
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
        JobQueue     = "High priority job queue"
        Owner        = local.owner
        Purpose      = local.owner
      }
    }
  }

  job_definitions = {
    example = {
      name                  = local.name
      propagate_tags        = true
      platform_capabilities = ["FARGATE"]

      container_properties = jsonencode({
        command = ["ls", "-la;"]
        
        # image   = "public.ecr.aws/runecast/busybox:1.33.1"
        ## Below ECR Image URL should be updated.
        image    = "697350684613.dkr.ecr.us-east-1.amazonaws.com/encrypt-decrypt-s3-docker:latest"
        
        fargatePlatformConfiguration = {
          platformVersion = "LATEST"
        },
        
    # https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-properties-batch-jobdefinition-resourcerequirement.html
        resourceRequirements = [
          { type = "VCPU", value = "4" },
          { type = "MEMORY", value = "30720" }
        ],

        executionRoleArn = aws_iam_role.ecs_task_execution_role.arn
        jobRoleArn       = aws_iam_role.ecs_task_execution_role.arn
        
        logConfiguration = {
          logDriver = "awslogs"
          options = {
            awslogs-group         = aws_cloudwatch_log_group.this.id
            awslogs-region        = local.region
            awslogs-stream-prefix = local.name
          }
        }

        volumes = [
        {
          name = "efs",
          efsVolumeConfiguration = {
            fileSystemId            = aws_efs_file_system.efs.id
            transitEncryption       = "ENABLED"
            transit_encryption_port = 2049
          }
        }
        ],

        # https://aws.amazon.com/premiumsupport/knowledge-center/ecs-fargate-mount-efs-containers-tasks/
        mountPoints = [
            {
                sourceVolume  = "efs",
                containerPath = "/mnt/efs",
                readOnly      = false
            }
        ],

          
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
        JobDefinition = "S3 files encrypt decrypt compress crypto services"
        Owner         = local.owner
        Purpose       = local.owner
      }
    }
  }

  tags = local.tags
}

################################################################################
# Supporting Resources
################################################################################

module "vpc_batch_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = "${local.name}-vpc-endpoint"
  description = "Security group for VPC endpoints"
  vpc_id      = local.vpc_id # HARDOCE VPC_ID

  egress_with_cidr_blocks = [
    {
      from_port   = 0
      to_port     = 65535
      protocol    = "tcp"
      description = "egress ports"
      cidr_blocks = "0.0.0.0/0"
    }
  ]
  tags = local.tags
}

module "vpc_efs_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = "${local.name}-efs-sg"
  description = "Security group for EFS"
  vpc_id      = local.vpc_id # HARDCODE VPC_ID

  ingress_with_source_security_group_id = [
    {
      description              = "https from service one"
      rule                     = "https-443-tcp"
      source_security_group_id = module.vpc_batch_security_group.security_group_id
    },
    {
      description              = "nfs from service one"
      rule                     = "nfs-tcp"
      source_security_group_id = module.vpc_batch_security_group.security_group_id
    }
  ]

  ingress_with_self = [
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      description = "Container to VPC endpoint service"
      self        = true
    },
    {
      from_port   = 2049
      to_port     = 2049
      protocol    = "tcp"
      description = "EFS (NFS)"
      self        = true
      cidr_blocks = null
      self        = true
    },
  ]

  egress_cidr_blocks = ["0.0.0.0/0"]
  egress_rules       = ["all-all"]
  tags = local.tags
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "${local.name}-ecs-task-exec"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_execution_role.json
}

data "aws_iam_policy_document" "ecs_task_execution_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "ecs_task_s3full_access" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/batch/${local.name}"
  retention_in_days = 30

  tags = local.tags
}

#######################################################################
# # EFS
#######################################################################

# Creating the AWS EFS System policy to transition files into and out of the file system.
resource "aws_efs_file_system_policy" "policy" {

    file_system_id = aws_efs_file_system.efs.id
  
    # The EFS System Policy allows clients to mount, read and perform 
    # write operations on File system 
    # The communication of client and EFS is set using aws:secureTransport Option
    policy = <<POLICY
    {
    "Version": "2012-10-17",
    "Id": "Policy01",
    "Statement": [
        {
            "Sid": "Statement",
            "Effect": "Allow",
            "Principal": {
                "AWS": "*"
            },
            "Resource": "${aws_efs_file_system.efs.arn}",
            "Action": [
                "elasticfilesystem:ClientMount",
                "elasticfilesystem:ClientRootAccess",
                "elasticfilesystem:ClientWrite"
            ],
            "Condition": {
                "Bool": {
                    "aws:SecureTransport": "true"
                }
            }
        }
    ]
    }
    POLICY
}

# https://adamtheautomator.com/terraform-efs/
# Creating Amazon EFS File system
resource "aws_efs_file_system" "efs" {
    
    creation_token = "enc-dec-efs-fs"
    
    encrypted = true
    
    # Creating the AWS EFS lifecycle policy
    # Amazon EFS supports two lifecycle policies. Transition into IA and Transition out of IA
    # Transition into IA transition files into the file systems's Infrequent Access storage class
    # Transition files out of IA storage
    lifecycle_policy {
        transition_to_ia = "AFTER_7_DAYS"
    }
    
    # Tagging the EFS File system with its value as efs
    tags = {
        Name      = "enc-dec-efs-fs"
        Owner     = local.owner
        Purpose   = local.owner
    }
}

# Creating the EFS access point for AWS EFS File system
resource "aws_efs_access_point" "test" {
    file_system_id = aws_efs_file_system.efs.id
}

# Creating the AWS EFS Mount point in a specified Subnet 
# AWS EFS Mount point uses File system ID to launch.
resource "aws_efs_mount_target" "mount" {
    file_system_id  = aws_efs_file_system.efs.id
    count           = length(data.aws_subnets.example.ids)
    subnet_id       = tolist(data.aws_subnets.example.ids)[count.index]
    security_groups = [module.vpc_efs_security_group.security_group_id, module.vpc_batch_security_group.security_group_id]
}
