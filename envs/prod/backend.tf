# Seul fichier qui differe entre envs/dev et envs/prod : la cle du state.
# Le bucket est cree a la CLI (voir README), jamais par Terraform.
terraform {
  backend "s3" {
    bucket       = "novasphere-tfstate-hor"
    key          = "novasphere/prod/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
