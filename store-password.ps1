# Step 1: enter credentials interactively
$SecurePwd = Read-Host "Enter router admin password" -AsSecureString                       # Now it would only diaplay "System.Security.SecureString"

# Step 2: save password encrypted to a file (DPAPI, only your Windows user can decrypt)
$SecurePwd | ConvertFrom-SecureString | Out-File "$env:USERPROFILE\.router_pwd.txt"        # Now it is would display actuall encrypted password.

Write-Host "Password saved."
