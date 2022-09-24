

## Deployment Steps:

 We cannot use **AWS Cloudshell** to run terraform script. 
  We can run it either locally or launch an **AWS EC2**  instance to run this.

### 01 - Pre-request in EC2 Instance 

`sudo yum install -y yum-utils`

`sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo`

`sudo yum -y install terraform`

`amazon-linux-extras install docker`

To start Docker service in the EC2

`service docker start`

`yum install git`

## 02 - Terraform Steps

`terraform init`

`terraform plan`

To create the stack,

`terraform apply --auto-approve`

To destroy the stack,

`terraform destroy --auto-approve`



#### Reference:  
https://aws.amazon.com/blogs/compute/creating-a-simple-fetch-and-run-aws-batch-job/

