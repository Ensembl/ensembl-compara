#!/usr/bin/env perl
# See the NOTICE file distributed with this work for additional information
# regarding copyright ownership.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


# Release Coordinator, please update this file before starting every release
# and check the changes back into GIT for everyone's benefit.

# The only changes to this registry should be to update location of ncbi_taxonomy
# and current staging servers.

use strict;
use warnings;

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::Utils::Registry;

my $curr_release = $ENV{'CURR_ENSEMBL_RELEASE'};

# ---------------------- CURRENT CORE DATABASES---------------------------------

Bio::EnsEMBL::Registry->load_registry_from_url("mysql://ensro\@mysql-ens-sta-5:4684/$curr_release");

#------------------------COMPARA DATABASE LOCATIONS----------------------------------

# FORMAT: alias name => [ host, db_name ]
my $compara_dbs = {
    # necessary compara dbs
    'compara_references' => [ 'mysql-ens-compara-prod-2', 'ensembl_compara_references' ],

    'compara_halibut'    => [ 'mysql-ens-compara-prod-2', 'verasper_variegatus_compara_103' ],
};

Bio::EnsEMBL::Compara::Utils::Registry::add_compara_dbas( $compara_dbs );

# NCBI taxonomy database (also maintained by production team):
Bio::EnsEMBL::Compara::Utils::Registry::add_taxonomy_dbas({
    'ncbi_taxonomy' => [ 'mysql-ens-mirror-1', "ncbi_taxonomy_$curr_release" ],
});

# -------------------------------------------------------------------

1;
