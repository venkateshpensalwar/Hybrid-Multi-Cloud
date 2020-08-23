provider "aws" {
  region     = "ap-south-1"
  profile    = "venkatesh"
  version    = "~> 2.70"
}
resource "aws_db_instance" "RDS" {

    name = "wordpress"
    identifier = "sqldb"
    engine    = "mysql"
    engine_version  = "5.7"
    instance_class = "db.t2.micro"
    auto_minor_version_upgrade = true
    storage_type  = "gp2"
    allocated_storage    = 5
    max_allocated_storage = 10
    parameter_group_name = "default.mysql5.7"
    username = "venkatesh"
    password = "venkatesh143268"
    publicly_accessible = true
    port = 3306

}
output "aws_instance_mysql" {
    value = aws_db_instance.RDS.endpoint 
}