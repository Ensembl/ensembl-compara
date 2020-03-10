#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2020] EMBL-European Bioinformatics Institute
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

use strict;
use warnings;

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::Utils::Registry;

# Species found on both vertebrates and non-vertebrates servers
my @overlap_species = qw(saccharomyces_cerevisiae drosophila_melanogaster caenorhabditis_elegans);

# ---------------------- CURRENT CORE DATABASES----------------------------------

Bio::EnsEMBL::Registry->load_registry_from_url('mysql://ensro@mysql-ens-mirror-1.ebi.ac.uk:4240/98');
# But remove the non-vertebrates species
Bio::EnsEMBL::Compara::Utils::Registry::remove_species(\@overlap_species);
Bio::EnsEMBL::Compara::Utils::Registry::remove_multi();
# Non-Vertebrates server
Bio::EnsEMBL::Registry->load_registry_from_url('mysql://ensro@mysql-ens-mirror-3.ebi.ac.uk:4275/98');

# ---------------------- PREVIOUS CORE DATABASES---------------------------------

# No reuse
*Bio::EnsEMBL::Compara::Utils::Registry::load_previous_core_databases = sub {
};

#------------------------COMPARA DATABASE LOCATIONS----------------------------------


my $compara_dbs = {
    'compara_master'    => [ 'mysql-ens-compara-prod-4', 'ensembl_compara_master_create_hmm' ],
    'compara_members'   => [ 'mysql-ens-compara-prod-4', 'muffato_pan_load_members_100'  ],
};

Bio::EnsEMBL::Compara::Utils::Registry::add_compara_dbas( $compara_dbs );

# ----------------------NON-COMPARA DATABASES------------------------

# NCBI taxonomy database (also maintained by production team):
Bio::EnsEMBL::Compara::Utils::Registry::add_taxonomy_dbas({
    'ncbi_taxonomy' => [ 'mysql-ens-sta-1', "ncbi_taxonomy_100" ],
});

# -------------------------------------------------------------------

1;
