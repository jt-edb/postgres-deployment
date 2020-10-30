variable "os" {}
variable "ami_id" {}
variable "instance_count" {}
variable "pem_instance_count" {}
variable "synchronicity" {}
variable "vpc_id" {}
variable "instance_type" {}
variable "ebs_device_name" {}
variable "ssd_type" {}
variable "ssd_size" {}
variable "ssd_iops" {}
variable "ebs_size" {}
variable "ansible_pem_inventory_yaml_filename" {}
variable "os_csv_filename" {}
variable "add_hosts_filename" {}
variable "ssh_key_path" {}
variable "custom_security_group_id" {}
variable "cluster_name" {}
variable "created_by" {}

data "aws_subnet_ids" "selected" {
  vpc_id = var.vpc_id
}

resource "aws_key_pair" "key_pair" {
  key_name   = var.ssh_key_path
  public_key = file(var.ssh_key_path)
}

resource "aws_instance" "EDB_DB_Cluster" {
  count = var.instance_count

  ami = var.ami_id

  instance_type          = var.instance_type
  key_name               = aws_key_pair.key_pair.id
  subnet_id              = element(tolist(data.aws_subnet_ids.selected.ids), count.index)
  vpc_security_group_ids = [var.custom_security_group_id]


  root_block_device {
    delete_on_termination = "true"
    volume_size           = var.ssd_size
    volume_type           = var.ssd_type
    iops                  = var.ssd_type == "io2" ? var.ssd_iops : null
  }

  tags = {
    Name       = (var.pem_instance_count == "1" && count.index == 0 ? format("%s-%s", var.cluster_name, "pemserver") : (var.pem_instance_count == "0" && count.index == 1 ? format("%s-%s", var.cluster_name, "primary") : (count.index > 1 ? format("%s-%s%s", var.cluster_name, "standby", count.index) : format("%s-%s", var.cluster_name, "primary"))))
    Created_By = var.created_by
  }

  connection {
    #user = "ubuntu"
    private_key = file(var.ssh_key_path)
  }

}

resource "aws_ebs_volume" "ebs-vol" {
  count = var.instance_count

  availability_zone = aws_instance.EDB_DB_Cluster[count.index].availability_zone
  size              = var.ebs_size
  type              = var.ssd_type
  iops              = var.ssd_type == "io2" ? var.ssd_iops : null

  tags = {
    Name = (var.pem_instance_count == "1" && count.index == 0 ? format("%s-%s", var.cluster_name, "ebs-pemserver") : (var.pem_instance_count == "0" && count.index == 1 ? format("%s-%s", var.cluster_name, "ebs-primary") : (count.index > 1 ? format("%s-%s%s", var.cluster_name, "ebs-standby", count.index) : format("%s-%s", var.cluster_name, "ebs-primary"))))
  }
}

resource "aws_volume_attachment" "attached-vol" {
  count = var.instance_count

  device_name = var.ebs_device_name
  volume_id   = aws_ebs_volume.ebs-vol[count.index].id
  instance_id = aws_instance.EDB_DB_Cluster[count.index].id
}
