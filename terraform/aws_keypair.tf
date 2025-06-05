resource "aws_key_pair" "tf_key" {
  key_name   = "${local.prefix}-key-${random_id.env_display_id.hex}"
  public_key = tls_private_key.rsa-4096-example.public_key_openssh
}

# RSA key of size 4096 bits
resource "tls_private_key" "rsa-4096-example" {
  algorithm = "RSA"
  rsa_bits  = 4096

}

resource "local_file" "tf_key" {
  content         = tls_private_key.rsa-4096-example.private_key_pem
  filename        = "${path.module}/sshkey-${aws_key_pair.tf_key.key_name}.pem"
  file_permission = "0400"
}
