#!/usr/bin/make -f

DEVELOP_BRANCH := master
STABLE_BRANCH := release-4.x

switch-develop:
	git checkout $(DEVELOP_BRANCH)

switch-stable:
	git checkout $(STABLE_BRANCH)

push:
	git checkout $(STABLE_BRANCH)
	git push && git push --tags
	git checkout $(DEVELOP_BRANCH)
	git push && git push --tags

merge-devel:
	set -eu \
	&& b="`git branch --show-current`" \
	&& test -n "$$b" -a "$$b" != $(DEVELOP_BRANCH) -a "$$b" != $(STABLE_BRANCH) \
	&& set -x \
	&& git checkout $(DEVELOP_BRANCH) \
	&& git merge --ff-only "$$b" \
	&& git branch -d "$$b" \
	&& git status -v
