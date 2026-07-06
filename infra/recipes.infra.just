# Terraform recipes

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
