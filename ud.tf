provider "aws" {
  region     = "ap-south-1"
  profile    = "default"
}

#Creating Key Pair
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

# Create Security Group

resource "aws_security_group" "Allow_Traffic" {
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

#Launching Instance

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

#Creating and Attaching of Volume
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

#Creating S3 Bucket

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

#CloudFront

locals {
   s3_origin_id = "S3-${aws_s3_bucket.my_first_bucket.bucket}"
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
            "echo \"<img src='my_first_bucket'>\" >> /var/www/html/terrapage.html",
            "EOF"
        ]
  
  }
}
