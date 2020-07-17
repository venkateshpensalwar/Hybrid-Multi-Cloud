provider "aws" {
  region     = "ap-south-1"
  profile    ="venkatesh"
}

# Create Key-Pair

resource "tls_private_key" "My_Private_Key" {
  algorithm   = "RSA"
}
resource "local_file" "Private_key" {
    content     = tls_private_key.My_Private_Key.private_key_pem
    filename ="keymine.pem"
    file_permission = 0400 
}
resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = tls_private_key.My_Private_Key.public_key_openssh
}

output "Key_my"{
	  value = tls_private_key.My_Private_Key
}

# Creating Security group

resource "aws_security_group" "SSH-HTTP" {
  name        = "SSH-HTTP"
  description = "inbound traffic"

  ingress {
    description = "allowed ssh and http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
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
    Name = "SSh and HTTP Allowed sg"
  }
}

# Launching instance and installing WEB server and Git

resource "aws_instance" "MyOs" {
  ami           = "ami-052c08d70def0ac62"
  instance_type = "t2.micro"
  key_name      = aws_key_pair.deployer.key_name
  security_groups = [aws_security_group.SSH-HTTP.name]
  user_data     = <<-EOF
                  #!/bin/bash
                  sudo su
                  yum -y install httpd 
		              yum -y install git
                  sudo systemctl enable httpd
                  sudo systemctl start httpd
                  EOF
  tags = {
    Name = "RHEL0.8"
  }
}
output "DNS" {
  value = aws_instance.MyOs.public_dns
}

output "MyosOut"{

    value=aws_instance.MyOs.availability_zone
}

output "MyosOut2"{

    value=aws_instance.MyOs.id
}

# Launching new EBS volume

resource "aws_ebs_volume" "EBSmyos" {
  availability_zone = aws_instance.MyOs.availability_zone
  size              = 2

  tags = {
    Name = "EBSmyos"
  }
}
output "EBSout"{

        value=aws_ebs_volume.EBSmyos.id
}

# Attaching EBS volume

resource "aws_volume_attachment""EBS_Attach" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.EBSmyos.id
  instance_id = aws_instance.MyOs.id
  force_detach = true
  
	}

# Mounting the new EBS

resource "null_resource" "nullremote3"  {

depends_on = [
    aws_volume_attachment.EBS_Attach,
  ]


  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/venkatesh.LAPTOP-JPPQ8935.000/Downloads/AWS/newKey.pem")
    host     = aws_instance.MyOs.public_ip
  }

provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvdh",
      "sudo mount  /dev/xvdh  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/venkateshpensalwar/AWS-TerraForm.git /var/www/html/"
    ]
  }
}

# Launching S3 Bucket

resource "aws_s3_bucket" "serverbucket1" {
  bucket = "rhel-bucket-1"
  acl    = "public-read"

  tags = {
    Name        = "RHEL_Server_Bucket"
 }
}

# uploading File to S3 Bucket

resource "aws_s3_bucket_object" "object" {
  bucket = aws_s3_bucket.serverbucket1.bucket
  key    = "WallpaperStudio10-1792.jpg"
  acl = "public-read"
  source = file("C:/Users/venkatesh.LAPTOP-JPPQ8935.000/Pictures/Saved Pictures/WallpaperStudio10-1792.jpg")
}

# Creating origin accesses identity for Cloud Front

resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  comment = "rhel-server-cloudfront"
}
output "oai"{

        value=aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path
}

# Creating Cloud Front Distrubuation

locals {
  s3_origin_id = "myS3Origin"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = aws_s3_bucket.serverbucket1.bucket_regional_domain_name
    origin_id   = local.s3_origin_id

    s3_origin_config {
      origin_access_identity =aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path
    }
  }
	enabled = true
	is_ipv6_enabled = true
	

  default_cache_behavior {
    allowed_methods  = [ "GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  # Cache behavior with precedence 0
  ordered_cache_behavior {
    path_pattern     = "/content/immutable/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false
      headers      = ["Origin"]

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  # Cache behavior with precedence 1
  ordered_cache_behavior {
    path_pattern     = "/content/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }



  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["US", "IN"]
    }
  }

  tags = {
    Environment = "production"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}