# Getting Started with Apple Developer License

## 🚀 First-Time Apple Developer Setup Guide

Since you've never used your Apple Developer license, here's a complete walkthrough to get you ready for AutoRip2MKV-Mac distribution.

## Step 1: Access Your Apple Developer Account

### 1.1 Sign into Developer Portal
1. Go to [https://developer.apple.com/account/](https://developer.apple.com/account/)
2. Sign in with your Apple ID (the one associated with your developer license)
3. You should see "Apple Developer Program" status as "Active"

### 1.2 Verify Your Membership
- **Account Holder**: You (or your organization)
- **Membership Status**: Active
- **Membership Expiration**: Should show your renewal date
- **Team ID**: Write this down! (10-character code like "AB12CD34EF")

## Step 2: Create Your First Certificate

### 2.1 Generate Certificate Signing Request (CSR)
1. **Open Keychain Access** (Applications → Utilities → Keychain Access)
2. **Menu**: Keychain Access → Certificate Assistant → Request a Certificate from a Certificate Authority
3. **Fill out the form**:
   - User Email Address: Your Apple ID email
   - Common Name: Your name or company name
   - CA Email Address: Leave blank
   - Request is: "Saved to disk" ✓
   - "Let me specify key pair information" ✓
4. **Save as**: `AutoRip2MKV-CertificateRequest.certSigningRequest`
5. **Key Size**: 2048 bits
6. **Algorithm**: RSA
7. Click "Continue" and save to Desktop

### 2.2 Create Developer ID Application Certificate
1. **Go to**: [Certificates Page](https://developer.apple.com/account/resources/certificates/list)
2. **Click**: "+" (plus sign) to create new certificate
3. **Select**: "Developer ID Application" (under "Production" section)
4. **Click**: "Continue"
5. **Upload**: The `.certSigningRequest` file you just created
6. **Click**: "Continue"
7. **Download**: The certificate (`.cer` file)
8. **Double-click** the downloaded certificate to install it in Keychain

### 2.3 Verify Certificate Installation
1. **Open Keychain Access**
2. **Select**: "My Certificates" in left sidebar
3. **Look for**: "Developer ID Application: [Your Name]"
4. **Expand it**: Should show a private key underneath
5. **Note**: The certificate name for later reference

## Step 3: Get Your App-Specific Password

### 3.1 Create App-Specific Password
1. **Go to**: [https://appleid.apple.com](https://appleid.apple.com)
2. **Sign in** with your Apple ID
3. **Go to**: "Sign-In and Security" section
4. **Find**: "App-Specific Passwords"
5. **Click**: "Generate Password"
6. **Label it**: "AutoRip2MKV-Mac Distribution"
7. **Copy the password**: Format will be `xxxx-xxxx-xxxx-xxxx`
8. **Save it safely**: You'll need this for distribution

### 3.2 Why App-Specific Password?
- Required for command-line tools (like notarization)
- More secure than using your main Apple ID password
- Can be revoked independently if compromised

## Step 4: Configure Your Development Environment

### 4.1 Create Your Credentials File
```bash
# In your AutoRip2MKV-Mac project directory:
cp .env.example .env
```

### 4.2 Edit .env with Your Real Values
```bash
# Replace these with your actual values:
APPLE_ID=your-actual-email@example.com
APPLE_ID_PASSWORD=your-app-specific-password-from-step-3
TEAM_ID=YOUR_TEAM_ID_FROM_STEP_1
```

### 4.3 Verify Everything Works
```bash
# Run the setup script to verify
./scripts/setup-distribution.sh
```

**Expected output:**
```
✓ Swift 6.2 installed and working
✓ codesign available  
✓ hdiutil available
✓ Xcode command line tools
✓ Found 1 Developer ID Application certificate(s)
✓ APPLE_ID: your-email@example.com
✓ APPLE_ID_PASSWORD: [hidden]
✓ TEAM_ID: YOUR_TEAM_ID
```

## Step 5: Test Your First Distribution

### 5.1 Run a Test Build
```bash
# This will build, sign, and create a DMG
./scripts/distribute.sh
```

### 5.2 What Happens During First Distribution
1. **Swift Build**: Compiles your app
2. **Code Signing**: Signs with your Developer ID certificate
3. **App Bundle Creation**: Creates proper .app structure
4. **DMG Creation**: Builds installer disk image
5. **Notarization**: Sends to Apple for security review (takes 5-15 minutes)
6. **Stapling**: Attaches approval ticket to your files

### 5.3 Expected Files Created
- `build/AutoRip2MKV-Mac.app` - Your signed application
- `AutoRip2MKV-Mac-v1.2.4.dmg` - Distribution installer

## Step 6: Understanding the Process

### 6.1 Code Signing Explained
- **Purpose**: Proves the app comes from you (not malware)
- **Certificate**: Links your app to your Developer ID
- **Signature**: Prevents tampering after signing
- **Verification**: Users can verify it's really from you

### 6.2 Notarization Explained
- **Purpose**: Apple scans for malware
- **Process**: Automated security review
- **Time**: Usually 5-15 minutes
- **Result**: Approval ticket attached to your app
- **Benefit**: Works on all modern macOS versions

### 6.3 Distribution Explained
- **DMG File**: Standard macOS installer format
- **User Experience**: Download → Open DMG → Drag to Applications
- **Security**: All modern Macs will trust your signed app

## Common First-Time Issues

### Issue 1: "No certificates found"
**Solution**: Make sure you completed Step 2 (creating and installing certificate)

### Issue 2: "Invalid app-specific password"
**Solution**: 
- Verify you're using app-specific password (not main password)
- Check for typos in .env file
- Regenerate password if needed

### Issue 3: "Team ID not found"
**Solution**: 
- Get Team ID from developer.apple.com/account → Membership
- It's a 10-character code like "AB12CD34EF"

### Issue 4: "Notarization failed"
**Solution**: 
- First-time notarization might take longer
- Check Apple Developer system status
- Verify all components are properly signed

## Next Steps After First Success

### For Regular Use
```bash
# Build and distribute in one command:
./scripts/distribute.sh

# Build without notarization (faster for testing):
./scripts/distribute.sh --no-notarize
```

### For Updates
1. Update version number in scripts
2. Run distribution
3. Test the new DMG
4. Distribute to users

## Getting Help

### Apple Resources
- [Developer Support](https://developer.apple.com/support/)
- [Code Signing Guide](https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/Introduction/Introduction.html)
- [Notarization Guide](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)

### Project Resources
- `DISTRIBUTION_GUIDE.md` - Complete distribution manual
- `CREDENTIALS_SETUP.md` - Security and credential management
- `./scripts/setup-distribution.sh` - Environment verification

## Congratulations! 🎉

Once you complete these steps, you'll have:
- ✅ Active Apple Developer certificate
- ✅ Secure credential storage
- ✅ Working distribution pipeline  
- ✅ Professional app distribution capability

**Your first app distribution is just one command away:** `./scripts/distribute.sh`

Welcome to macOS app development! 🚀