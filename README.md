# Ensembl Compara API

[![Build Status](https://travis-ci.org/Ensembl/ensembl-compara.svg?branch=master)](https://travis-ci.org/Ensembl/ensembl-compara)
[![Coverage Status](https://coveralls.io/repos/Ensembl/ensembl-compara/badge.svg?branch=master&service=github)](https://coveralls.io/github/Ensembl/ensembl-compara?branch=master)

[travis]: https://travis-ci.org/Ensembl/ensembl-compara
[coveralls]: https://coveralls.io/r/Ensembl/ensembl-compara

The Ensembl Compara API (Application Programme Interface) serves as a
middle layer between the underlying MySQL database and the user's script.
It aims to encapsulate the database layout by providing high level access
to the database.

Find more information (including the installation guide and a tutorial) on
the Ensembl website: http://www.ensembl.org/info/docs/api/compara/

See [the main Ensembl repository](https://github.com/Ensembl/ensembl/blob/HEAD/CONTRIBUTING.md)
for the guidelines on user contributions

## Installation

If working with HAL files, additional setup is required. First, install progressiveCactus:

	git clone git://github.com/glennhickey/progressiveCactus.git
	cd progressiveCactus
	git pull
	git submodule update --init
	cd submodules/hal/
	git checkout master
	git pull
	cd ../../
	make
	export PROGRESSIVE_CACTUS_DIR=$PWD

Now, we need to set up the Compara API:

	cd ensembl-compara/xs/HALXS
	perl Makefile.PL
	make

## Contact us

Please email comments or questions to the public Ensembl developers list at
http://lists.ensembl.org/mailman/listinfo/dev

Questions may also be sent to the Ensembl help desk at
http://www.ensembl.org/Help/Contact

![e!Compara word cloud](docs/ebang-wordcloud.png)
