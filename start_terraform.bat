@echo off
echo ================================
echo Starting Terraform Deployment...
echo ================================

:: Initialize Terraform
terraform init
if errorlevel 1 (
    echo Terraform init failed!
    exit /b 1
)

:: Plan Terraform changes
terraform plan
if errorlevel 1 (
    echo Terraform plan failed!
    exit /b 1
)

:: Apply Terraform changes automatically
terraform apply -auto-approve
if errorlevel 1 (
    echo Terraform apply failed!
    exit /b 1
)

echo ================================
echo Terraform Deployment Complete!
echo ================================
pause
