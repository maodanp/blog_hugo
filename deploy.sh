#!/bin/bash

echo -e "\033[0;32mDeploying updates to GitHub...\033[0m"

# Build the project.
hugo

# Add changes to git.
git add -A

# Commit changes.
msg="rebuilding site `date`"
if [ $# -eq 1 ]
  then msg="$1"
fi
git commit -m "$msg"

# Push source and build repos.
git push origin master
echo "hugo blog has commited"

rm -rf ../maodanp.github.io/*
cp -rf ../public_git/* ./maodanp.github.io
cp -rf ./public/* ../maodanp.github.io
cd ../maodanp.github.io/

git add -A
git commit -m "$msg"
git push origin master
echo "public files has commited"

