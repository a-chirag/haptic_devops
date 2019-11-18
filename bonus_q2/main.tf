
provider "aws" {
  version = "~> 2.9"
  region  = "ap-south-1"
  access_key = "ACCESS_KEY"
  secret_key = "SECRET_KEY"
}
variable "wordpress_version" {
  default = "5.3"
}
variable "path" {
  default = "/"
}
resource "aws_instance" "web" {
  ami           = "ami-0d2e8ef01c8b6708d"
  instance_type = "t2.micro"

  provisioner "file" {
    source      = "question2/install-wordpress.sh"
    destination = "/tmp/install-wordpress.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/install-wordpress.sh",
      "/tmp/install-wordpress.sh --version ${var.wordpress_version} --path ${var.path}",
    ]
  }
}
