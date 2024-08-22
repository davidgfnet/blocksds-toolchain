
Just run the "run.sh" script and you will get a built toolchain under the
'toolchain' directory.

This repo includes Fedora building rules (see my copr at
https://copr.fedorainfracloud.org/coprs/davidgf/blocksds/) and Debian/Ubuntu
(launchpad at https://launchpad.net/~david-davidgf/+archive/ubuntu/blocksds-sdk)

To generate a Fedora src.rpm you need to generate a tree and copy files:

```
  rpmdev-setuptree                                    # Create RPMBUILD tree
  ./run.sh download                                   # Get sources if missing
  cp download/* patches/* run.sh ~/rpmbuild/SOURCES/  # Copy source files
  cp fedora-specs/* ~/rpmbuild/SPECS/                 # Copy specs
  rpmbuild -bs ~/rpmbuild/SPECS/blocksds.spec         # Outputs an src.rpm file
```

To build an Ubuntu src.deb you can do (you need gpg setup):

```
  # Generate a source tar.gz image
  export VERSION="1.2.3-4"                            # Setup version (as in changelog)
  ./run.sh download                                   # Get sources if missing
  tar -czf ../blocksds-sdk_$VERSION.orig.tar.gz download/* patches/* run.sh  debian/* Makefile

  mkdir ../blocksds-sdk-$VERSION                      # Create source dir
  cd ../blocksds-sdk-$VERSION
  tar xf ../blocksds-sdk_$VERSION.orig.tar.gz         # Extract dir locally

  # Generate source deb and upload to launchpad
  dpkg-buildpackage --build=source -kemail@example.com
  dput ppa:user/repo ../blocksds-sdk_$VERSION_source.changes
```


