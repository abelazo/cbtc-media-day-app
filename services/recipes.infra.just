# Terraform recipes

# Clean up
[group('init')]
clean:
  @echo "Cleaning up..."
  rm -f .config.local.tfbackend
  rm -rf .terraform

# Create tfbackend config
[group('init')]
setup env +args="":
  @echo 'Creating tfbackend for {{BOLD + RED}}{{ env }}{{NORMAL}} environment'
  cp .config.tfbackend.example .config.local.tfbackend
  sed -i.bak "s|<terraform.state.bucket>|$TF_STATE_BUCKET|" .config.local.tfbackend
  sed -i.bak "s|<aws.region>|$AWS_REGION|" .config.local.tfbackend
  rm -f .config.local.tfbackend.bak

# Initialize Terraform (with backend)
[group('init')]
init env="dev" +args="": (clean) (setup env)
  @echo 'Initalizing for {{BOLD + RED}}{{ env }}{{NORMAL}} environment'
  terraform init --reconfigure --backend-config=.config.local.tfbackend {{args}}

# Initialize Terraform (no backend)
[group('init')]
init_no_backend +args="":
  @echo 'Initalizing without environment'
  terraform init --reconfigure --backend=false {{ args }}

# Workspaces
[group('state')]
workspace env="dev" +args="":
  @echo 'Selecting workspace for {{BOLD + RED}}{{ env }}{{NORMAL}} environment'
  terraform workspace select {{ args }} {{ lowercase(env) }}

# Plan Terraform changes
[group('apply')]
plan env="dev" +args="":
  terraform plan --var="environment={{ env }}" {{ args }}

# Apply Terraform changes
[group('apply')]
apply env="dev" +args="":
  terraform apply --var="environment={{ env }}" {{ args }}

# Apply all changes
[group('apply')]
init-apply env +args="": (init env '--reconfigure') (apply env args)

# Destroy infrastructure (with confirmation)
[group('apply')]
destroy env:
  @echo "⚠️  WARNING: This will destroy infrastructure!"
  terraform destroy --var="environment={{ env }}"

# Output
[group('apply')]
output env +args="":
  terraform output

# Format Terraform files
[group('lint')]
fmt:
  terraform fmt --recursive

# Validate Terraform configuration
[group('lint')]
validate:
  terraform validate

# Lint Terraform configuration
[group('lint')]
lint:
  tflint --init
  tflint --recursive

# Checkov
[group('lint')]
checkov:
  checkov --directory . --framework terraform

# Trivy
[group('lint')]
trivy:
  trivy --exit-code 1 --severity HIGH,CRITICAL config .

# Check
[group('lint')]
check: fmt validate lint checkov trivy
