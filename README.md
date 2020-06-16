#  DEPLOYMENT OF INFRASTRUCTURE USING TERRAFORM 

## TERRAFORM

**Terraform** is an open source “Infrastructure as Code” tool, created by **HashiCorp**. A declarative coding tool, Terraform 
enables developers to use a high-level configuration language called **HCL (HashiCorp Configuration Language)** to describe
the desired “end-state” cloud or on-premises infrastructure for running an application. It then generates a plan for reaching
that end-state and executes the plan to provision the infrastructure.

## AWS (Amazon Web Services)

**Amazon Web Services (AWS)** is the world’s most comprehensive and broadly adopted cloud platform, offering over **175 fully 
featured services** from data centers globally. Millions of customers—including the fastest-growing startups, largest 
enterprises, and leading government agencies—are using AWS to lower costs, become more agile, and innovate faster.


***Prerequisite for this you should have preinstalled Terraform in your system and also you should have your AWS account ready.***


## Here is a basic overview that what we have to do for deploying the whole Infrastructure using TerraForm.

1. We will create the key and security group which allow the port 80.

2. Launch EC2 instance.

3. In this Ec2 instance we will use the key and security group which we have created in step 1.

4. Launch one Volume (EBS) and mount that volume into /var/www/html.

5. Developer have uploded the code into github repo also the repo has some images.

6. Copy the github repo code into /var/www/html

7. We will create S3 bucket, copy/deploy the images from Github repo into the S3 bucket and change the permission to public readable.

8 Create a CloudFront using S3 bucket(which contains images) and use the CloudFront URL to update in code in /var/www/html.

Now let's go through it step by step.

### Create the key:

Here, I have used RSA algorithm to create a key-pair. This works on two different types of keys i.e Public key and Private key.

``` provider "aws" {
  region     = "ap-south-1"
  profile    = "default"
}
resource "tls_private_key" "UDIT" {
    algorithm = "RSA"
}
resource "local_file" "private_key" {
    content         =   tls_private_key.UDIT.private_key_pem
    filename        =   "mykey1.pem"
}
resource "aws_key_pair" "mykey1" {
    key_name   = "mykey_1"
    public_key = tls_private_key.UDIT.public_key_openssh
}
```

### Create Security group which allow the port 80 and 22:

Here, I am defining our AWS ingress and egress rules. According to our needs, I have taken HTTP and SSH. By default, AWS 
creates an ALLOW ALL egress rule when creating a new Security Group inside of a VPC.

```resource "aws_security_group" "Allow_Traffic" {
  name        = "Security_Guard"
  description = "Allow inbound traffic"
  vpc_id      = "vpc-759f821d"

  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    
  }

  tags = {
    Name = "Security_Guard"
  }
}

```
### Launch EC2 instance:

Now, I have launched an EC2 Instance using the key and security group we have created above. Here I have defined
AMI (Amazon Machine Image), Instance type, Key-Name, Security group, etc. I have used Provisioner here. 
Provisioner works on resources like executing commands etc. In this case, I have used Provisioner to install 
WebServer and Github in our launched Instance.

```
resource "aws_instance" "FIRST_OS" {
  ami           = "ami-0447a12f28fddb066"
  instance_type   = "t2.micro"
  key_name  =  aws_key_pair.mykey1.key_name
  security_groups  = [aws_security_group.Allow_Traffic.name]
  root_block_device {
        volume_type     = "gp2"
        volume_size     = 8
        delete_on_termination   = true
    }


    connection {
        type     = "ssh"
        user     = "ec2-user"
        private_key = tls_private_key.UDIT.private_key_pem
        host     = aws_instance.FIRST_OS.public_ip
  }


    provisioner "remote-exec" {
        inline = [
          "sudo yum install httpd  php  -y",
          "sudo systemctl restart httpd",
          "sudo systemctl enable httpd",
          "sudo yum install git -y"
    ]
  }
    tags = {
      Name = "TerraFormOS"
    }
}
```
### Launch one Volume (EBS), mount that volume into /var/www/html and copy the code from Github repo:

Here, I have launched EBS Volume and then we have attached this volume with our Instance. As discussed above here also I 
have used Provisioner to create partitions and mount the volume. After connecting I have downloaded code from the Github repo.

```
resource "aws_ebs_volume" "FirstOS_vol" {
    availability_zone = aws_instance.FIRST_OS.availability_zone
    size              = 1
    type = "gp2"
    tags = {
        Name = "myTerraVol"
    }
}
resource "aws_volume_attachment" "vol_attach" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.FirstOS_vol.id
  instance_id = aws_instance.FIRST_OS.id
  force_detach = true
  
}

resource "null_resource" "NullRemote"  {


    depends_on = [
       aws_volume_attachment.vol_attach,
   ]


    connection {
        type     = "ssh"
        user     = "ec2-user"
        private_key = tls_private_key.UDIT.private_key_pem
        port    = 22
        host     = aws_instance.FIRST_OS.public_ip
   }


  provisioner "remote-exec" {
      inline = [
          "sudo mkfs.ext4  /dev/xvdf",
          "sudo mount  /dev/xvdf  /var/www/html",
          "sudo rm -rf /var/www/html/*",
          "sudo git clone https://github.com/Uditanshu0110/HTML_CODE.git /var/www/html/"
     ]
   }
 }
 ```
 
 ### Create S3 bucket, deploy the images from Github repo into the S3 bucket and change the permission to public readable:
 
 Now, I have created an S3 bucket and set the access method into a public-read.
 
 ```
 resource "aws_s3_bucket" "my_first_bucket" {
     bucket  = "uditanshuimg"
     acl     = "public-read"


 }


 resource "aws_s3_bucket_object" "uploadingimages" {
      bucket = aws_s3_bucket.my_first_bucket.bucket
      key    = "TerraForm1.png"
      source = "/Users/uditanshupandey/Downloads/Images/TerraForm1.png"
      acl    = "public-read"
  
}
```

### Create a CloudFront using S3 bucket(which contains images) and use the CloudFront URL to update in code in /var/www/html:

Till now we have created our Key-Pair, Security group, Instance, Volumes, and S3 Buckets. Now its time to CloudFront (Content Delivery Network) 
which is used to decrease the latency period.

```
locals {
   s3_origin_id = "S3-aws_s3_bucket.my_first_bucket.bucket"
 }



resource "aws_cloudfront_distribution" "s3_distribution_network" {
  origin {
    domain_name = aws_s3_bucket.my_first_bucket.bucket_domain_name
   origin_id   = local.s3_origin_id
  }

  enabled     = true
 
 default_cache_behavior {    
     allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${local.s3_origin_id}"


     forwarded_values {
       query_string = false


       cookies {
         forward = "none"
       }
     }


     viewer_protocol_policy = "allow-all"
    
   }
  


   restrictions {
     geo_restriction {
       restriction_type = "none"
      
     }
    }


   viewer_certificate {
     cloudfront_default_certificate = true
  }
  connection {
        type    = "ssh"
        user    = "ec2-user"
        host    = aws_instance.FIRST_OS.public_ip
        port    = 22
        private_key = tls_private_key.UDIT.private_key_pem
    }
provisioner "remote-exec" {
        inline  = [
            "sudo su << EOF",
            "echo \"<img src='my_first_bucket'>\" >> /var/www/html/udit.html",
            "EOF"
        ]
  
  }
}
```
Commands to execute this script:

### For Initializing Plugins command is - *** terraform init ***
### For Deploying and Launching command is - *** terraform apply ***
### For Destroying command is - *** terraform destroy ***

