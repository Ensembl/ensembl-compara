#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2019] EMBL-European Bioinformatics Institute
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
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

my $curr_release = $ENV{'CURR_ENSEMBL_RELEASE'};
my $prev_release = $curr_release - 1;

# ---------------------CURRENT CORE DATABASES------------------------

# The majority of core databases live on staging servers:
# Bio::EnsEMBL::Registry->load_registry_from_url(
#    "mysql://ensro\@mysql-ens-sta-1.ebi.ac.uk:4519/$curr_release");
Bio::EnsEMBL::Registry->load_registry_from_url(
    "mysql://ensro\@mysql-ens-vertannot-staging:4573/$curr_release");

# Add in extra cores from genebuild server:
# my $extra_core_dbs = {
#     'cyprinus_carpio_german_mirror' => [ 'mysql-ens-vertannot-staging', "cyprinus_carpio_germanmirror_core_99_10" ],
#     'cyprinus_carpio_hebao_red'     => [ 'mysql-ens-vertannot-staging', "cyprinus_carpio_hebaored_core_99_10" ],
# };
#
# Bio::EnsEMBL::Compara::Utils::Registry::add_core_dbas( $extra_core_dbs );

#---------------------COMPARA DATABASE LOCATIONS---------------------

Bio::EnsEMBL::Compara::Utils::Registry::add_compara_dbas({
    'compara_master' => [ 'mysql-ens-compara-prod-8', $ENV{'USER'} . '_compara_master_citest' ],
});

# -------------------------------------------------------------------

1;
