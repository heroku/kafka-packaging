# Confluent Kafka Packaging
#
# The 'master' branch contains a script for packaging a plain archive file,
# including a more standardized (i.e. non-Java project) layout. Other branches,
# e.g. 'debian' build on this basic functionality. In order to support
# traditional installation, a normal 'install' target is provided, and the
# default 'archive' target just compresses the target prefix directory. Note
# that for safety and testing, the default PREFIX is specified relative to the
# working directory.
#
# In order to use any of the branches, including this one, you must merge it
# with the Kafka code. We use this model since it makes packaging some
# distributions, such as debian, much simpler since the normally use
# overlay-based packaging. You should start by generating a new branch for the
# type of package and Kafka version you're releasing:
#
#     git checkout -b archive-0.8.2
#
# and then merge in the upstream tree, presumably a tagged version:
#
#     git merge 0.8.2
#
# and finally create the package:
#
#     make archive
#
# which will generate kafka-0.8.2.tar.gz in this case. Note that the version
# used in these scripts is determined automatically by looking at tags, so it is
# not affected by the branch name 'archive-0.8.2'; that name is purely for you
# to keep track of release branches. Since the branch is a simple merge, it can
# be discarded after generating the release.
#
# In order to be able to apply patches cleanly and repeatably, this script *will
# use git-reset to clean out any changes that aren't already committed to the
# tree*. You need to make sure the changes you want applied are either:
# a) in the Kafka source tree, b) committed to the archive packaging branch, or
# c) in the form of a patch in patches/ and listed in patches/series.
#
# Dependencies you'll probably need to install to compile this: make, curl, git,
# zip, unzip, java7-jdk | openjdk-7-jdk.

GRADLE_VERSION=2.2.1
GRADLE=./gradle-$(GRADLE_VERSION)/bin/gradle

# Release specifics. Note that some of these (VERSION, SCALA_VERSION, DESTDIR)
# are required and passed to create_archive.sh as environment variables. That
# script can also pick up some other settings (PREFIX, SYSCONFDIR) to customize
# layout of the installation.
tag=$(shell git describe --abbrev=0)
ver=$(shell echo $(tag) | sed -e 's/kafka-//' -e 's/-incubating-candidate-[0-9]//')
ifndef VERSION
VERSION=$(ver)
endif

ifndef SCALA_VERSION
SCALA_VERSION=$(shell grep ext[.]scalaVersion scala.gradle | awk -F\' '{ print $$2 }')
endif
SCALA_VERSION_UNDERSCORE=$(subst .,_,$(SCALA_VERSION))

PACKAGE_NAME=kafka-$(VERSION)-$(SCALA_VERSION)

# Whether we should apply patches. This only makes sense for alternate packaging
# systems that know how to apply patches themselves, e.g. Debian.
ifndef APPLY_PATCHES
APPLY_PATCHES=yes
endif

# Install directories
ifndef DESTDIR
DESTDIR=$(CURDIR)/$(PACKAGE_NAME)
endif
ifndef PREFIX
PREFIX=/usr/local
endif

export VERSION
export SCALA_VERSION
export DESTDIR
export PREFIX
export SYSCONFDIR

all: install


archive: install
	cd $(DESTDIR) && tar -czf $(CURDIR)/$(PACKAGE_NAME).tar.gz .
	cd $(DESTDIR) && zip -r $(CURDIR)/$(PACKAGE_NAME).zip .

gradle: gradle-$(GRADLE_VERSION)

gradle-$(GRADLE_VERSION):
	curl -O -L "https://services.gradle.org/distributions/gradle-$(GRADLE_VERSION)-bin.zip"
	unzip gradle-$(GRADLE_VERSION)-bin.zip
	rm -rf gradle-$(GRADLE_VERSION)-bin.zip

apply-patches: $(wildcard patches/*)
	git reset --hard HEAD
ifeq ($(APPLY_PATCHES),yes)
	cat patches/series | xargs -iPATCH bash -c 'patch -p1 < patches/PATCH'
endif

kafka: gradle apply-patches
	$(GRADLE) -PscalaVersion=$(SCALA_VERSION)
	./gradlew -PscalaVersion=$(SCALA_VERSION) releaseTarGz_$(SCALA_VERSION_UNDERSCORE)

# create_archive gets the
install: kafka
	./create_archive.sh

clean:
	rm -rf $(CURDIR)/gradle-*
	rm -rf $(DESTDIR)$(PREFIX)
	rm -rf $(CURDIR)/$(PACKAGE_NAME)*

.PHONY: clean install
