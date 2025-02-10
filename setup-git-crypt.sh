#!/bin/bash

################################################################################
# Boiler plate
################################################################################

# uncomment this to for debugging
#set -x

# Aggressively catch and report errors
set -euo pipefail
function handle_error {
    local exit_status=$?
    echo "An error occurred on line $LINENO: $BASH_COMMAND"
    exit $exit_status
}
trap handle_error ERR


# Path to this script
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

TMP_DIR="$SCRIPT_DIR/tmp"
mkdir -p $TMP_DIR

################################################################################

# For recreating this git repo
#THIS_GIT_REPO='git@github.com:pwyoung/test-git-crypt.git'
THIS_GIT_REPO='https://github.com/philwyoungatinsight/test-git-crypt.git'

# Store the encryption key at BACKUP_GIT_CRYPT_KEY_FILE
REPO_BASE_NAME=$(basename "$THIS_GIT_REPO")
BACKUP_GIT_CRYPT_KEY_DIR="$HOME/GIT-CRYPT-BACKUP-KEYS"
BACKUP_GIT_CRYPT_KEY_FILE="$BACKUP_GIT_CRYPT_KEY_DIR/git-crypt-key.$REPO_BASE_NAME"

# Githib account parameters (used to fetch any existing GPG keys)
GH_USER='philwyoungatinsight'
GH_ORG='Insight-NA'
# Store the resulting response from GitHub here (when we get the public GPG key for $GH_USER)
GH_GPG_RESPONSE_FILE="$TMP_DIR/$GH_USER.gpgkeys.txt"

# GPG Key Parameters (used to identify an existing key, or create one if it was not found)
GPG_REAL_NAME='Phillip Young'
GPG_EMAIL="phil.young@insight.com"

# Bash
BASH_TRUE=0
BASH_FALSE=1

# Relative path (from repo top dir) to files that should be encrypted
TEST_FILE_1="./config/secrets/custom-settings.sh"
TEST_FILE_2="./config/secrets/backups/custom-settings.sh"

install_git_crypt() {
    if git-crypt --version; then
        return
    fi

    if uname | grep Darwin; then
        brew install git-crypt
    fi

    if uname | grep -i ubuntu; then
        sudo apt-get install -y git-crypt
    fi

    if git-crypt --version; then
        echo "Install git-crypt"
        echo "see: https://github.com/AGWA/git-crypt/blob/master/INSTALL.md"
        exit 1
    fi

    git-crypt --version
}

git_crypt_init_repo() {
    cd $(git rev-parse --show-toplevel)

    if ls -ld ./.git/git-crypt/*; then
        echo "This repo is encrypted"
        return
    fi

    echo "Initializing git report via git-crypt"
    git-crypt init
    echo "Just ran: git-crypt init"

    echo "All files: ls -a"
    ls -a

    echo "git-crypt files:  ls -ld ./.git/git-crypt/*"
    ls -ld ./.git/git-crypt/*
    #read -p "Hit enter to continue"
}

backup_git_encrypt_key() {
    echo "Backing up the actual encryption key"
    mkdir -p $BACKUP_GIT_CRYPT_KEY_DIR
    git-crypt export-key $BACKUP_GIT_CRYPT_KEY_FILE
    echo "The BACKUP_GIT_CRYPT_KEY_FILE is here:"
    ls -l $BACKUP_GIT_CRYPT_KEY_FILE
    #read -p "hit enter"
}

update_git_attributes_with_git_crypt_filters() {
    cd $(git rev-parse --show-toplevel)

    if [ -e .gitattributes ]; then
        if cat .gitattributes | grep 'git-crypt'; then
            echo ".gitattributes already has git-crypt filters."
            echo "The current file is"
            cat .gitattributes
            read -p "Hit enter to recreate the file"
            echo "" >.gitattributes
        fi
    else
        echo "" >.gitattributes
    fi

    # Works to encrypt one file
    #F='config/secrets/custom-settings.sh'
    #echo "$F filter=git-crypt diff=git-crypt" >> .gitattributes

    # Encypt files ending in '.secret'
    #echo "*.secret filter=git-crypt diff=git-crypt" >> .gitattributes

    # Encrypt files in the dir ./config/secrets (and its subdirs)
    echo "config/secrets/** filter=git-crypt diff=git-crypt" >> .gitattributes


    # Add .gitattributes to git
    git add .gitattributes
}

replace_test_files() {
    cd $(git rev-parse --show-toplevel)
    rm -rf ./config
    mkdir -p ./config/secrets/backups

    # This is not a secret
    echo "this.is.not.a.secret.txt" > ./config/this.is.not.a.secret.txt

    # These should be git-encrypted
    echo "this.is.a.secret.txt.secret" > $TEST_FILE_1
    echo "this.is.a.secret.txt.secret" > $TEST_FILE_2
}

commit_to_git() {
    cd $(git rev-parse --show-toplevel)

    git add ./config

    #git add .git-crypt

    git commit -m"testing git-crypt `date`"
    git push -u origin main
}

test_decryption_via_backup_key() {
    GIT_REMOTE=$(git remote -v | egrep '^origin' | tail -1 | awk '{print $2}')
    GIT_DIRNAME=$(cd $(git rev-parse --show-toplevel) && basename `pwd`)

    D=/tmp/test-git-crypt-via-backup-key
    rm -rf $D
    mkdir $D
    cd $D

    git clone $GIT_REMOTE $GIT_DIRNAME
    ls -l ./$GIT_DIRNAME
    cd ./$GIT_DIRNAME

    echo "Cloned to `pwd`"
    #echo "Is the git-crypt encryption key visible now?"
    #ls -l ./.git/git-crypt/keys/default && echo "YES" || echo "NO"
    #read -p "Hit enter to continue"

    echo "Current dir is `pwd`"
    echo "Decrypt via encryption key"
    git-crypt unlock $BACKUP_GIT_CRYPT_KEY_FILE

    ls -l $TEST_FILE_1
    cat $TEST_FILE_1
    ls -l $TEST_FILE_2
    cat $TEST_FILE_2
}

test_decryption_via_gpg() {
    GIT_REMOTE=$(git remote -v | egrep '^origin' | tail -1 | awk '{print $2}')
    GIT_DIRNAME=$(cd $(git rev-parse --show-toplevel) && basename `pwd`)

    D=/tmp/test-git-crypt-via-gpg
    rm -rf $D
    mkdir -p $D
    cd $D

    git clone $GIT_REMOTE $GIT_DIRNAME
    ls -l ./$GIT_DIRNAME
    cd ./$GIT_DIRNAME

    echo "Cloned to `pwd`"
    #echo "Is the git-crypt encryption key visible now?"
    #ls -l ./.git/git-crypt/keys/default && echo "YES" || echo "NO"
    #read -p "Hit enter to continue"

    echo "Current dir is `pwd`"
    echo "Decrypt via GPG-key"
    git-crypt unlock

    ls -l $TEST_FILE_1
    cat $TEST_FILE_1
    ls -l $TEST_FILE_2
    cat $TEST_FILE_2
}


# Fetch a public GPG Key for $GH_USER from Github
get_public_gpg_key_from_github() {
    # Fetch GPG keys
    echo "Fetching GPG keys for ${GH_USER}..."
    response=$(curl -s \
                    -H "Accept: application/vnd.github.v3+json" \
                    -H "X-GitHub-Api-Version: 2022-11-28" \
                    "https://api.github.com/users/${GH_USER}/gpg_keys")


    # Check if response is an error
    if echo "$response" | grep -q '"message"'; then
        echo "Error: Failed to fetch GPG keys"
        echo "$response"
        exit 1
    fi

    # Save to file
    echo "$response" > "$GH_GPG_RESPONSE_FILE"

    if cat $GH_GPG_RESPONSE_FILE | grep 'BEGIN PGP PUBLIC KEY BLOCK' >/dev/null; then
        return $BASH_TRUE
    else
        return $BASH_FALSE
    fi
}

create_local_gpg_key() {
    #PROTECTION='%no-protection'
    PROTECTION='%ask-passphrase'

    F=$TMP_DIR/gpg.key.config
    cat <<EOF >$F
%echo Generating GPG key
Key-Type: RSA
Key-Length: 4096
Subkey-Type: RSA
Subkey-Length: 4096
Name-Real: $GPG_REAL_NAME
Name-Email: $GPG_EMAIL
Expire-Date: 0
$PROTECTION
%commit
%echo Done
EOF

    # Generate the key
    gpg --batch --generate-key $F
}

read_local_gpg_key() {
    if ! gpg --list-keys --keyid-format=long "$GPG_EMAIL"; then
        echo "There is no GPG key for $GPG_EMAIL"
        return $BASH_FALSE
    fi

    if ! gpg --list-secret-keys --keyid-format=long "$GPG_EMAIL"; then
        echo "There is no GPG secret key for $GPG_EMAIL"
        return $BASH_FALSE
    fi

    GPG_KEY_ID=$(gpg --list-keys --keyid-format=long "$GPG_EMAIL" | egrep -A 1 '^pub' | tail -1 | awk '{print $1}')
    #echo "GPG_KEY_ID=$GPG_KEY_ID"

    GPG_KEY_ARMORED_DATA=$(gpg --armor --export $GPG_KEY_ID)
    #echo "GPG_KEY_ARMORED_DATA=$GPG_KEY_ARMORED_DATA"

    return $BASH_TRUE
}

add_gpg_key_to_github_manually() {
    echo "Add following the GPG key to GitHub"
    echo ""
    echo "GPG_KEY_ID=$GPG_KEY_ID"
    echo ""
    echo "GPG_KEY_ARMORED_DATA"
    echo "$GPG_KEY_ARMORED_DATA"
    echo ""
    echo "Instructions here: https://docs.github.com/en/authentication/managing-commit-signature-verification/adding-a-gpg-key-to-your-github-account"
    echo ""
    echo "Paste the GPG key in at https://github.com/settings/gpg/new"
    if command -v open; then
        open https://github.com/settings/gpg/new
    fi
    read -p "open the web page and enter the key and then hit enter here"
    echo ""
    echo "View keys here: https://github.com/settings/keys"
    read -p "open the web page and view the key and then hit enter here"
}


add_gpg_key_to_github() {
    add_gpg_key_to_github_manually

    if get_public_gpg_key_from_github; then
        echo "Found newly created Public GPG key in GitHub"
    else
        echo "Did not find newly created Public GPG key in GitHub"
        exit 1
    fi
}

get_or_create_public_gpg_key() {
    if get_public_gpg_key_from_github; then
        echo "Found a Public GPG key in GitHub"
    else
        echo "Did not find a Public GPG key in GitHub"
        if read_local_gpg_key; then
            echo "Read the local GPG key"
            echo "GPG_KEY_ID=$GPG_KEY_ID"
            echo "GPG_KEY_ARMORED_DATA=$GPG_KEY_ARMORED_DATA"
        else
            echo "Did not find a local GPG key"
            create_local_gpg_key
            if ! read_local_gpg_key; then
                echo "Failed to read the GPG key that was just created"
                exit 1
            fi
            echo "GPG_KEY_ID=$GPG_KEY_ID"
            echo "GPG_KEY_ARMORED_DATA=$GPG_KEY_ARMORED_DATA"
        fi
        echo "Did not find a public GPG key in GitHub"
        read -p "hit enter to continue and add one"
        add_gpg_key_to_github
    fi
}

delete_local_gpg_key() {
    echo "This will delete your local GPG key (and wipe out the private key)"
    echo "Are you sure?"
    read -p "Hit enter to proceed"

    N=$(gpg --list-keys | wc -l)
    if [[ $N -eq 0 ]]; then
        echo "No local GPG keys were found"
    else
        GPG_KEY=$(gpg --list-keys | egrep -A 1 '^pub' | tail -1 | awk '{print $1}')
        gpg --delete-key $GPG_KEY || true
    fi

    N=$(gpg --list-secret-keys | wc -l)
    if [[ $N -eq 0 ]]; then
        echo "No local secret GPG keys were found"
    else
        GPG_KEY=$(gpg --list-secret-keys | egrep -A 1 '^sec' | tail -1 | awk '{print $1}')
        gpg --delete-secret-key $GPG_KEY || true
    fi
}

recreate_git_repo() {
    rm -rf ./.git
    rm -rf ./.git-crypt
    rm -rf ./.gitattributes

    git init
    git checkout -b main

    git add ./README.md

    # Gitignore
    cat <<EOF > .gitignore
tmp
EOF
    git add ./.gitignore

    # Other files
    git add ./*.md
    git add ./*.sh

    git commit -m"initial commit"
    git remote add origin $THIS_GIT_REPO
    git push --set-upstream origin main -f
}

check_git_crypt_status() {
    #echo "Show git-crypt status of all files"
    #git-crypt status

    echo "Show git-crypt status of encrypted files only"
    git-crypt status -e

    # Error if there are files that should be encrypted (as of the CURRENT .gitattributes) but aren't
    git-crypt status -f

    read -p "Just showed git-crypt status. hit enter to continue"
}

add_users() {
    echo ""
    gpg --list-keys $GPG_EMAIL

    # The GPG Key ID is in the line after "pub ..."
    GPG_KEY_ID=$(gpg --list-keys --keyid-format=long "$GPG_EMAIL" | egrep -A 1 '^pub' | tail -1 | awk '{print $1}')
    git-crypt add-gpg-user $GPG_KEY_ID

    echo "This has the encryption key, encrypted with the user's public key"
    ls -ld ./.git-crypt/keys/default/0/* || echo "This dir is usually here"

    read -p "Added users. hit enter to continue"
}

main() {
    install_git_crypt

    # Remove the local GPG key (during dev)
    #delete_local_gpg_key
    get_or_create_public_gpg_key

    recreate_git_repo
    git_crypt_init_repo
    update_git_attributes_with_git_crypt_filters
    backup_git_encrypt_key

    replace_test_files
    add_users
    commit_to_git

    check_git_crypt_status

    test_decryption_via_backup_key
    test_decryption_via_gpg
}

main
