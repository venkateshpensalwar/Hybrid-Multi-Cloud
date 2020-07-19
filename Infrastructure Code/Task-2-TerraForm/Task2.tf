# provider

provider "aws" {
  profile = "venkatesh"
  region = "ap-south-1"
  version = "~> 2.70"
  
}

# Security group that allows NFS

resource "aws_security_group" "allow_nfs" {
  name = "NFS-sg"
  description = "Allow HTTP, SSH and EFS inbound traffic"
   ingress {
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
  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# AWS EC2 instance

resource "aws_instance" "Task-2" {
   ami          = "ami-0447a12f28fddb066"
  instance_type = "t2.micro" 
  key_name       = "newKey"
  security_groups = [aws_security_group.allow_nfs.name]

  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/venkatesh.LAPTOP-JPPQ8935.000/Downloads/AWS/newKey.pem")
    host     =   aws_instance.Task-2.public_ip
  }
  provisioner "remote-exec"{
    inline = [
      "sudo yum install git -y",
      "sudo yum install httpd -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
      "sudo systemctl enable httpd",
      "sudo yum install -y amazon-efs-utils"
    ]    
  }      
  tags  = {
    Name = "Task-2"
  } 
}

# EFS creation

resource "aws_efs_file_system" "efs" {
  creation_token = "EFS"


  tags = {
    Name = "efs_storage"
  }
}
resource "aws_efs_mount_target" "efs_mount" {
  file_system_id     = aws_efs_file_system.efs.id
  subnet_id             = aws_instance.Task-2.subnet_id
  security_groups   = [ aws_security_group.allow_nfs.id ]
}

# AWS S3 Bucket creation

resource "aws_s3_bucket" "serverbucket1" {
  bucket = "task-2-bucket"
  acl    = "public-read"

  tags = {
    Name    = "Server_Bucket"
 }
}


# Uploading images on S3

resource "aws_s3_bucket_object" "object" {
  depends_on = [aws_s3_bucket.serverbucket1]
  bucket = "task-2-bucket"
  key    = "WallpaperStudio10-1792.jpg"
  source = "C:/Users/venkatesh.LAPTOP-JPPQ8935.000/Pictures/Saved Pictures/WallpaperStudio10-1792.jpg"
  content_type= "image/jpg"
  acl    ="public-read"
}

# Creating origin accesses identity for Cloud Front

resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  comment = "rhel-server-cloudfront"
}
output "oai"{

        value=aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path
}

locals {
    s3_origin_id = "myS3Origin"
  }

# Cloud Front Distrubution

resource "aws_cloudfront_distribution" "s3_distribution" {
  depends_on = [aws_s3_bucket_object.object]
  origin {
    domain_name = aws_s3_bucket.serverbucket1.bucket_regional_domain_name
    origin_id   = local.s3_origin_id
}
  
  enabled             = true
  default_root_object = "WallpaperStudio10-1792.jpg"   


 default_cache_behavior 
 {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
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
      restriction_type = "none"
    }
  }
  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

# Null resources

resource "null_resource" "null1" {


depends_on = [
    aws_efs_mount_target.efs_mount,
    aws_instance.Task-2,
    aws_cloudfront_distribution.s3_distribution, 
]
connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key =  file("C:/Users/venkatesh.LAPTOP-JPPQ8935.000/Downloads/AWS/newKey.pem")
    host     = aws_instance.Task-2.public_ip
  }
provisioner "remote-exec"{
    inline = [ 
      "sudo mount -t efs '${aws_efs_file_system.efs.id}':/ /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/venkateshpensalwar/Hybrid-Multi-Cloud.git /var/www/html/",
      "sudo su <<EOF" , "echo \"<center><img src='http://${aws_cloudfront_distribution.s3_distribution.domain_name}/${aws_s3_bucket_object.object.key} width=500px'><center>\"  >> /var/www/html/index.html" , "EOF", 
      ]   
  }
}

