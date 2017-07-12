#!/bin/bash 

git config --global user.name "YangWJ"
git config --global user.email "339823220@qq.com"
git config --global core.editor vim

git config --global alias.co checkout
git config --global alias.br branch
git config --global alias.ci commit
git config --global alias.st status
git config --global alias.unstage 'reset HEAD --'
git config --global alias.last 'log -1 HEAD'
git config --global alias.stash-unapply '!git stash show -p | git apply -R'

git config --global color.ui true

git config --global merge.tool extMerge
git config --global mergetool.extMerge.cmd \
    'extMerge "$BASE" "$LOCAL" "$REMOTE" "$MERGED"'
git config --global mergetool.trustExitCode false
git config --global diff.external extDiff

git config --global core.autocrlf input
git config --global core.whitespace \
    trailing-space,space-before-tab,indent-with-non-tab
