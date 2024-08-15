%global buildroot_ver  1.3.1

Name:           blocksds-sdk
Epoch:          1
Version:        1.3.1
Release:        1%{?dist}
Summary:        BlocksDS SDK and ARM toolchain targeting the Nintendo DS

# Most of the sources are licensed under GPLv3+ with these exceptions:
# LGPLv2+ libquadmath/ libjava/libltdl/ gcc/testsuite/objc.dg/gnu-encoding/generate-random 
#         libgcc/soft-fp/ libffi/msvcc.sh
# LGPLv3+ gcc/prefix.c
# BSD libgo/go/regexp/testdata/testregex.cz zlib/example.c libffi/ 
#     libjava/classpath/external/relaxngDatatype/org/relaxng/datatype/helpers/DatatypeLibraryLoader.java
# GPLv2+ libitm/testsuite/libitm.c/memset-1.c libjava/
# Public Domain libjava/classpath/external/sax/org/xml/sax/ext/EntityResolver2.java
#               libjava/classpath/external/sax/org/xml/sax/ext/DeclHandler.java
# BSL zlib/contrib/dotzlib/DotZLib/GZipStream.cs
License:        GPLv3+ and LGPLv2+ and MIT and CC0
URL:            https://blocksds.github.io/docs/

Source0:	run.sh
Source1:	download/binutils-2.42.tar.xz
Source2:	download/blocksds-ceab784229051cb5e1473a346645443c1987f5cd.tar.xz
Source3:	download/gcc-14.1.0.tar.xz
Source4:	download/picolibc-1.8.6.tar.xz
Source5:	patches/cross-thumb.txt
Source6:	patches/picolibc.specs
Source7:	patches/gcc14-poison-system-directories.patch

BuildRequires:  perl-ExtUtils-MakeMaker perl-Thread-Queue perl-FindBin perl-English
BuildRequires:	autoconf mpfr mpfr-devel libmpc libmpc-devel isl isl-devel gmp gmp-devel
BuildRequires:	make ncurses-devel wget bc rsync
BuildRequires:  gcc gcc-c++ flex meson ninja-build
BuildRequires:  zlib-devel libzstd libzstd-devel
BuildRequires:  make git tar xz texinfo bison pkgconf
Requires: mpfr libmpc isl gmp libzstd
Requires: glibc
Requires: libgcc
AutoReqProv: no

%undefine _missing_build_ids_terminate_build
%global debug_package %{nil}
%global __strip /bin/true
%global _build_id_links alldebug

%description
BlocksDS SDK is a Nintendo DS open source SDK. It ships a GCC/picolibc based
ARM toolchain to be able to build homebrew applications for the platform.

%prep
%setup -q -c -T
mkdir -p download/ patches/
cp %{SOURCE0} .
cp %{SOURCE1} %{SOURCE2} %{SOURCE3} %{SOURCE4} download/
cp %{SOURCE5} %{SOURCE6} %{SOURCE7} patches/

%build
# Disable format-security since GCC14 has a couple of format warnings
# export CXXFLAGS="$CXXFLAGS -Wno-error=format-security"
unset CXXFLAGS
unset CFLAGS
unset LDFLAGS

bash ./run.sh

%install
export QA_RPATHS=$[ 0xFFFF ]
mkdir -p %{buildroot}/opt
cp -r toolchain %{buildroot}/opt/blocksds-toolchain

%files
/opt/blocksds-toolchain/*

%changelog
* Sun Aug 04 2024 David Guillen Fandos <david@davidgf.net> - 1.3.1-1
- First version

