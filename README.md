# Ensembl Compara API

[![Build Status](https://travis-ci.org/Ensembl/ensembl-compara.svg?branch=main)](https://travis-ci.org/Ensembl/ensembl-compara)
[![Codecov Status](https://codecov.io/gh/ensembl/ensembl-compara/branch/main/graph/badge.svg)](https://codecov.io/github/Ensembl/ensembl-compara)
[![Code Climate](https://api.codeclimate.com/v1/badges/2dd3c490030a5af7ff21/maintainability.svg)](https://codeclimate.com/github/Ensembl/ensembl-compara)

The Ensembl Compara API (Application Programme Interface) serves as a
middle layer between the underlying MySQL database and the user's script.
It aims to encapsulate the database layout by providing high level access
to the database.

Find more information (including the installation guide and a tutorial) on
the Ensembl website: <http://www.ensembl.org/info/docs/api/compara/>

See [the main Ensembl repository](https://github.com/Ensembl/ensembl/blob/main/CONTRIBUTING.md)
for the guidelines on user contributions.

## Installation

### Perl modules

We use a number of Perl modules that are all available on CPAN. We recommend using cpanminus to install these.
You will need both the [Core API
dependencies](https://github.com/Ensembl/ensembl/blob/main/cpanfile) and
[ours](cpanfile).

### API to access HAL alignments (progressive-Cactus)

If working with HAL files, additional setup is required. There are several ways
of installing the dependencies.

#### Complete installation of progressive-Cactus

Follow this procedure if you intend to run the cactus aligner. If Cactus is
already installed on your system, you can directly jump to the section
about setting up the API. Otherwise, do this:

	git clone https://github.com/glennhickey/progressiveCactus.git
	cd progressiveCactus
	# Make sure we use the latest version
	git pull
	# Download the dependencies
	git submodule update --init
	
	# We specifically need a more recent version of "hal"
	cd submodules/hal/
	git checkout master
	git pull
	cd ../..
	
	cd submodules/sonLib
	# edit include.mk and add " -fPIC" at the end of the cflags_opt line (line 44)
	cd ../..
	
	# Compile
	make
	# Check it passes the test-suite. You should see "Result: PASS"
	make test
	pwd  # Prints the installation path

Note that on some Ubuntu installations, you may have to do this as well:

        sudo apt-get install python-dev
        sudo ln -s /usr/lib/python2.7/plat-*/_sysconfigdata_nd.py /usr/lib/python2.7/

Now, we need to set up the Compara API:

	cd ensembl-compara/src/perl/xs/HALXS
	perl Makefile-progressiveCactus.PL path/to/cactus
	make

If you have the `PROGRESSIVE_CACTUS_DIR` environment variable defined, you
can skip `path/to/cactus` on the Makefile command-line, e.g.:

	cd ensembl-compara/src/perl/xs/HALXS
	perl Makefile-progressiveCactus.PL
	make

On the EBI main cluster, *do not* load
`/nfs/software/ensembl/latest/envs/basic.sh` in your `.bashrc`, and replace
`perl` with `/nfs/software/ensembl/latest/linuxbrew/bin/perl` when invoking
`Makefile-progressiveCactus.PL`.

#### Installation via Linuxbrew

If you have a Linuxbrew installation of Ensembl that includes HAL, do this
instead:

	cd ensembl-compara/src/perl/xs/HALXS
	perl Makefile-Linuxbrew.PL path/to/linuxbrew_home
	make

If you have the `LINUXBREW_HOME` environment variable defined, you can skip
`path/to/linuxbrew_home` on the Makefile command-line.

#### Separate installation of all dependencies

On many OSes you may be able to install hdf5 system-wide via your software
manager. This usually brings in regular security updates etc. Then, you
need to install these two libraries:

* [sonLib](https://github.com/benedictpaten/sonLib)
* [hal](https://github.com/ComparativeGenomicsToolkit/hal)

You will have to patch `sonLib/include.mk` like in the progressiveCactus
instructions above. Then run this makefile

	cd ensembl-compara/src/perl/xs/HALXS
	perl Makefile-hdf5@OS.PL path/to/sonLib path/to/hal
	make

If you can't have hdf5 installed system-wide, install it manually from:

* [hdf5](https://support.hdfgroup.org/HDF5/)

And run this makefile

	cd ensembl-compara/src/perl/xs/HALXS
	perl Makefile.PL path/to/hdf5 path/to/sonLib path/to/hal
	make

### Additional data files (e.g. HAL alignments)

Alignments using the _method_ `CACTUS_HAL` or `CACTUS_HAL_PW` require extra
files to be downloaded from
<ftp://ftp.ensembl.org/pub/data_files/multi/hal_files/> in order to be fetched with the
API. The files must have the same name as on the FTP and must be placed
under `multi/hal_files/` within your directory of choice.
Finally, you need to define the environment variable `COMPARA_HAL_DIR` to
the latter.

## Contact us

Please email comments or questions to the public Ensembl developers list at
<http://lists.ensembl.org/mailman/listinfo/dev>

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>

![e!Compara word cloud](docs/ebang-wordcloud.png)
