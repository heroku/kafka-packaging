Debian Build Instructions
=========================

This branch contains a build configuration for Debian. It's largely the same as
the master branch except that the data has been moved into debian/ to match
Debian's required layout. You can use this branch to generate packages for any
Debian-based distro, and building anywhere should support all distributions as
long as the basic installation requirements can be met. Note that we only ever
specify 'unstable' in the control file. You should never need to use any other
value. Promotion into specific distributions is handled outside this repository.

Because we need to have different packages for different versions of Kafka, we
can't actually check in the final `debian/control` file since the Package: line
needs to be changed for different builds. Currently you need to handle this
manually by generating the control file yourself. This is due to the strict
requirements Debian build tools impose on source packages and unexpected files
in the source tree.

Prerequisites
-------------

You probably want to do all of this in a VM. Using Vagrant is probably a good
idea. We don't currently include the Vagrantfile because Debian's build system
doesn't like having the extra files lying around and it would conflict with
Kafka's own Vagrantfile.

Install some required build packages:

    $ sudo apt-get install git-buildpackage

Now create the build environment. The distribution doesn't actually matter much
since we are building a generic package anyway.

    $ sudo DIST=trusty git-pbuilder create --components "main universe"

This step often takes awhile since it downloads and installs a base OS, but it's
a one-time step.

Building
--------

In your copy of this `kafka-packaging` repository, make sure you have the
`upstream` remote which contains the Kafka source, including tags.

    $ cd kafka-packaging.git
    $ git remote add upstream http://git-wip-us.apache.org/repos/asf/kafka.git
    $ git fetch upstream

Now, start a branch for the version you want to release, starting it from the
current `debian` branch. We'll use 0.8.2-beta as an example here:

    $ git checkout -b debian-0.8.2-beta debian

We need to generate the control file, selecting which Scala version we're
building for:

    $ export SCALA_VERSIONS="2.9.1 2.9.2 2.10.1 2.11.5"
    $ make -f debian/Makefile debian-control

Now, merge in the real Kafka source code, assuming a tagged release:

    $ git merge 0.8.2-beta

Now you can do the actual build:

    $ sudo DIST=trusty git-buildpackage -us -uc --git-builder="git-pbuilder" --git-cleaner="fakeroot debian/rules clean" --git-debian-branch=debian-0.8.2-beta --git-upstream-tag=0.8.2-beta --git-verbose

after which you should find build artifacts in the parent directory (which, if
you're using a stock Vagrant setup and running in the /vagrant directory, will
be under root:

    $ ls /kafka*
    /kafka_0.8.2~beta-1_amd64.build  /kafka_0.8.2~beta-1_amd64.changes
    /kafka_0.8.2~beta-1.debian.tar.gz /kafka_0.8.2~beta-1.dsc
    /kafka_0.8.2~beta.orig.tar.gz  /kafka-2.10.1_0.8.2~beta-1_all.deb

Finally, you can clean up. The branch was purely for git-buildpackage and
doesn't contain any important changes that need to be saved, so you can just
delete it:

    $ git checkout debian
    $ git branch -D debian-0.8.2-beta

You probably want to test the package. You should probably do that in a
separate, clean, base VM using `dpkg -i`.
