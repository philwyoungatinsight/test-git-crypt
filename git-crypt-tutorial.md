# Setting up and Using git-crypt

## Installation

### On macOS:
```bash
brew install git-crypt
```

### On Ubuntu/Debian:
```bash
sudo apt-get install git-crypt
```

## Initial Setup

1. Initialize a new Git repository:
```bash
mkdir secure-project
cd secure-project
git init
```

2. Initialize git-crypt in the repository:
```bash
git-crypt init
```

#  tree ./.git/git-crypt
# ./.git/git-crypt
# └── keys
#     └── default



3. Create a .gitattributes file to specify which files should be encrypted:
```bash
# Create and edit .gitattributes
echo "*.secret filter=git-crypt diff=git-crypt" >> .gitattributes
echo "secretdir/** filter=git-crypt diff=git-crypt" >> .gitattributes
```

## Adding Collaborators

1. Export your key for backup:
```bash
git-crypt export-key ~/git-crypt-key
```

# git-crypt export-key ~/GIT-CRYPTS/git-crypt-key.k8s-recipes


2. Add a collaborator using their GPG key:
```bash
# First, import their public key if you haven't already
gpg --import collaborator-public-key.gpg

# Then add them to git-crypt
git-crypt add-gpg-user user@example.com
```

## Usage Example

1. Create a secret file:
```bash
echo "API_KEY=1234567890" > credentials.secret
```

2. Add and commit files:
```bash
git add .gitattributes credentials.secret
git commit -m "Add encrypted credentials"
```

3. Verify encryption:
```bash
# The file should appear encrypted
cat credentials.secret
```

4. Push to remote repository:
```bash
git remote add origin git@github.com:username/secure-project.git
git push -u origin main
```

## For Collaborators

1. Clone the repository:
```bash
git clone git@github.com:username/secure-project.git
cd secure-project
```

2. Unlock the repository (if using GPG):
```bash
git-crypt unlock
```

3. Or unlock using the exported key:
```bash
git-crypt unlock /path/to/git-crypt-key
```

## Best Practices

1. Files to encrypt:
   - API keys and secrets
   - Configuration files with sensitive data
   - Private certificates
   - Environment files (.env)

2. Files to never encrypt:
   - The .gitattributes file itself
   - Public certificates
   - Documentation
   - Sample configuration files

3. Security considerations:
   - Always backup your git-crypt key
   - Use strong GPG keys for team members
   - Regularly audit who has access
   - Consider rotating keys periodically

## Troubleshooting

If files appear corrupted:
```bash
# Re-lock the repository
git-crypt lock

# Unlock it again
git-crypt unlock
```

If you need to start over:
```bash
# Remove git-crypt
rm -rf .git/git-crypt

# Reinitialize
git-crypt init
```

## Common Commands Reference

```bash
# Initialize git-crypt
git-crypt init

# Lock repository
git-crypt lock

# Unlock repository
git-crypt unlock

# Add GPG user
git-crypt add-gpg-user USER_ID

# Export key
git-crypt export-key /path/to/key

# Status of encrypted files
git-crypt status
```
