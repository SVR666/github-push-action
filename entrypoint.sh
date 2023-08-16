#!/bin/sh -l

WORKDIR="$GITHUB_WORKSPACE"
USER_NAME="$1"
USER_EMAIL="$2"
COMMIT_MESSAGE="$3"
TARGET_REPO="$4"
COPY_FROM_LOCATION="$5"
REMOVE_LIST="$6"

# Code taken from https://github.com/cpina/github-action-push-to-another-repository/blob/main/entrypoint.sh
# Verify that there (potentially) some access to the destination repository
# and set up git (with GIT_CMD variable) and GIT_CMD_REPOSITORY
if [ -n "${SSH_DEPLOY_KEY:=}" ]
then
	echo "[+] Using SSH_DEPLOY_KEY"

	# Inspired by https://github.com/leigholiver/commit-with-deploy-key/blob/main/entrypoint.sh , thanks!
	mkdir --parents "$HOME/.ssh"
	DEPLOY_KEY_FILE="$HOME/.ssh/deploy_key"
	echo "${SSH_DEPLOY_KEY}" > "$DEPLOY_KEY_FILE"
	chmod 600 "$DEPLOY_KEY_FILE"

	SSH_KNOWN_HOSTS_FILE="$HOME/.ssh/known_hosts"
	ssh-keyscan -H "github.com" > "$SSH_KNOWN_HOSTS_FILE"

	export GIT_SSH_COMMAND="ssh -i "$DEPLOY_KEY_FILE" -o UserKnownHostsFile=$SSH_KNOWN_HOSTS_FILE"

	GIT_CMD_REPOSITORY="git@github.com:$USER_NAME/$TARGET_REPO.git"

elif [ -n "${API_TOKEN_GITHUB:=}" ]
then
	echo "[+] Using API_TOKEN_GITHUB"
	GIT_CMD_REPOSITORY="https://$USER_NAME:$API_TOKEN_GITHUB@github.com/$USER_NAME/$TARGET_REPO.git"
else
	echo "::error::API_TOKEN_GITHUB and SSH_DEPLOY_KEY are empty. Please fill one (recommended the SSH_DEPLOY_KEY)"
	exit 1
fi

# Setup git
git config --global user.name "$USER_NAME"
git config --global user.email "$USER_EMAIL"

git config --global http.version HTTP/1.1

git clone "$GIT_CMD_REPOSITORY"

# Check if the input is empty
if [ -z "$REMOVE_LIST" ]; then
  echo "[+] REMOVE_LIST not provided"
else
  # Split input into an array using spaces as the separator
  list=($REMOVE_LIST)

  for item in "${list[@]}"; do
    path="$TARGET_REPO/$item"

    echo "[+] Deleting $path"
	rm -rf "$path"
  done
fi

# rm -rf "$TARGET_REPO"/assets "$TARGET_REPO"/svg "$TARGET_REPO"/vendor "$TARGET_REPO"/index.html
cp -r "$COPY_FROM_LOCATION" "$TARGET_REPO"

echo "[+] Set directory is safe ($TARGET_REPO)"
# Related to https://github.com/cpina/github-action-push-to-another-repository/issues/64
git config --global --add safe.directory "$TARGET_REPO"

cd "$TARGET_REPO"

echo "[+] Adding git commit"
git add .

echo "[+] git status:"
git status

echo "[+] git diff-index:"
# git diff-index : to avoid doing the git commit failing if there are no changes to be commit
git diff-index --quiet HEAD || git commit --message "$COMMIT_MESSAGE"

echo "[+] Pushing git commit"
# --set-upstream: sets de branch when pushing to a branch that does not exist
git push origin main --set-upstream
