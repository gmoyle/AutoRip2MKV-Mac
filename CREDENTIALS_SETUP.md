# Secure Apple Developer Credentials Setup

## 🔐 Best Practices for Storing Credentials

Your Apple Developer credentials should **NEVER** be committed to Git. Here are secure storage options:

## Option 1: .env File (Recommended)

1. **Copy the example file:**
   ```bash
   cp .env.example .env
   ```

2. **Edit .env with your actual credentials:**
   ```bash
   # Your Apple ID email address
   APPLE_ID=your-actual-email@example.com
   
   # App-specific password from https://appleid.apple.com
   APPLE_ID_PASSWORD=your-actual-app-specific-password
   
   # Your Team ID from Apple Developer account
   TEAM_ID=YOUR_ACTUAL_TEAM_ID
   ```

3. **The .env file is already in .gitignore** - it won't be committed to Git

## Option 2: Shell Profile (Global)

Add to your `~/.zshrc` (or `~/.bash_profile`):

```bash
# Apple Developer Credentials
export APPLE_ID="your-actual-email@example.com"
export APPLE_ID_PASSWORD="your-actual-app-specific-password"  
export TEAM_ID="YOUR_ACTUAL_TEAM_ID"

# Reload with: source ~/.zshrc
```

## Option 3: Separate Credentials Script

1. **Create developer-credentials.sh:**
   ```bash
   #!/bin/bash
   export APPLE_ID="your-actual-email@example.com"
   export APPLE_ID_PASSWORD="your-actual-app-specific-password"
   export TEAM_ID="YOUR_ACTUAL_TEAM_ID"
   ```

2. **Make it executable:**
   ```bash
   chmod +x developer-credentials.sh
   ```

3. **This file is also in .gitignore**

## Getting Your Credentials

### Apple ID
- Your regular Apple ID email address

### App-Specific Password  
1. Go to [appleid.apple.com](https://appleid.apple.com)
2. Sign in and go to "Sign-In and Security"
3. Under "App-Specific Passwords", click "Generate Password"
4. Label it "AutoRip2MKV-Mac Distribution"
5. Copy the generated password (format: xxxx-xxxx-xxxx-xxxx)

### Team ID
1. Go to [Apple Developer Account](https://developer.apple.com/account/)
2. Sign in and go to "Membership" section
3. Your Team ID is shown (10-character alphanumeric, like "AB12CD34EF")

### Developer ID Certificate
1. Go to [Certificates](https://developer.apple.com/account/resources/certificates/list)
2. Click "+" to create new certificate
3. Select "Developer ID Application"
4. Follow instructions to generate and download
5. Double-click the downloaded .cer file to install in Keychain

## Credential Priority Order

The distribution scripts check for credentials in this order:

1. **`.env` file** (project-specific, recommended)
2. **`developer-credentials.sh`** (project-specific script)
3. **Environment variables** (from shell profile)
4. **Interactive prompts** (fallback)

## Security Tips

### ✅ DO:
- Use app-specific passwords (not your main Apple ID password)
- Keep credentials in .env or shell profile
- Use different credentials for different projects
- Regenerate app-specific passwords periodically

### ❌ DON'T:
- Commit credentials to Git repositories
- Share credentials in plain text
- Use your main Apple ID password
- Store credentials in project documentation

## Verification

Test that your credentials are loaded correctly:

```bash
# Run the setup script
./scripts/setup-distribution.sh

# Should show:
# ✓ APPLE_ID: your-email@example.com
# ✓ APPLE_ID_PASSWORD: [hidden]
# ✓ TEAM_ID: YOUR_TEAM_ID
```

## Troubleshooting

### "Environment variables not set"
- Check that .env exists and has correct syntax
- Ensure no spaces around the = sign
- Verify the file is in the project root directory

### "Invalid credentials" 
- Verify app-specific password is correct (not main password)
- Check Team ID matches your Developer account
- Ensure Developer ID certificate is installed

### "Permission denied"
- Make sure developer-credentials.sh is executable: `chmod +x developer-credentials.sh`

## Example Complete Setup

1. **Create .env file:**
   ```bash
   APPLE_ID=john.doe@example.com
   APPLE_ID_PASSWORD=abcd-efgh-ijkl-mnop
   TEAM_ID=AB12CD34EF
   ```

2. **Verify setup:**
   ```bash
   ./scripts/setup-distribution.sh
   ```

3. **Run distribution:**
   ```bash
   ./scripts/distribute.sh
   ```

Your credentials are now secure and ready for distribution! 🔐