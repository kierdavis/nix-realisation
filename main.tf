terraform {
  required_providers {
    external = {
      source = "hashicorp/external"
    }
  }
}

variable "flake_output" {
  type        = string
  description = <<-EOT
    A reference to an output of a Nix flake, in the form accepted by 'nix build'.
    For example, 'path:path/to/myflake#myoutput'.
    This output will be evaluated during the Terraform plan phase.
    The result of evaluation should be derivation, whose outputs will then be
    realised during the Terraform apply phase.
  EOT
}

variable "eval_options" {
  type = list(string)
  default = []
}

variable "create_derivation_gc_root" {
  type        = bool
  default     = true
  description = <<-EOT
    If true, a Nix garbage collector root will be created for the derivation.
    This can speed up the Terraform plan phase, particularly if evaluating the
    derivation requires realising store paths (i.e. import-from-derivation),
    at the of increase Nix store disk usage.
  EOT
}

variable "gc_root_id" {
  type = string
  default = null
}

variable "gc_root_dir" {
  type = string
  default = null
}

locals {
  gc_root_id = var.gc_root_id != null ? var.gc_root_id : md5(var.flake_output)
  gc_root_dir = var.gc_root_dir != null ? var.gc_root_dir : pathexpand("~/.cache/terraform-nix-realisation/gcroots")
}

data "external" "derivation" {
  program = ["nix-shell", "-p", "python3", "--run", "python3 ${path.module}/derivation.py"]
  query   = {
    flake_output = var.flake_output
    eval_options = jsonencode(var.eval_options)
    create_gc_root = var.create_derivation_gc_root
    gc_root_id = local.gc_root_id
    gc_root_dir = local.gc_root_dir
  }
}

locals {
  drv_path = data.external.derivation.result.drv_path
}

resource "terraform_data" "realisation" {
  triggers_replace = local.drv_path
  provisioner "local-exec" {
    command = "exec nix-store --realise ${local.drv_path}"
  }
}

data "external" "outputs" {
  depends_on = [terraform_data.realisation]
  program = ["nix-shell", "-p", "python3", "--run", "python3 ${path.module}/outputs.py"]
  query = {
    drv_path = local.drv_path
  }
}

output "derivation" {
  value = local.drv_path
}

output "outputs" {
  value = data.external.outputs.result
}
