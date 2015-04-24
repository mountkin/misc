#!/bin/bash
apt-get install -y exuberant-ctags vim
cp git-diff-wrapper /usr/bin
[ -d ~/.git_template ] || mkdir ~/.git_template
cp -r .git_template/* ~/.git_template
cp .gitconfig ~/
