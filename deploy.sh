#!/bin/sh

echo "Deploying myblog to github"

# generate static html, css file using hugo
hugo

# copy some static content to ./docs to publish
cp -rf ./static/pic ./docs/

git add -A :/

if [ $# -eq 1 ]; then
    git commit -m "$1"
else
    git commit
fi

# if no commit messager found, just exit
if [ $? -ne 0 ]; then
    exit 1
fi

# push to github
git push origin master

# copy docs folder to maodanp.github.io repo
cp -r ./docs/* ../maodanp.github.io/


# enter maodanp.github.io repo
cd ../maodanp.github.io/

git add .


if [ $# -eq 1 ]; then
    git commit -m "$1"
else
    git commit
fi

git push origin master
