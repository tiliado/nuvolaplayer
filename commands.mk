#!/usr/bin/make -f

devel:
	git checkout devel
master:
	git checkout master
sync:
	git checkout devel
	git push && git push --tags
	git checkout master
	git push && git push --tags
	git checkout devel
