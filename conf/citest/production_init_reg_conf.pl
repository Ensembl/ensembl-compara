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

use strict;
use warnings;

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::Utils::Registry;

my $curr_release = $ENV{'CURR_ENSEMBL_RELEASE'};
my $prev_release = $curr_release - 1;
my $curr_eg_release = $ENV{'CURR_EG_RELEASE'};
my $prev_eg_release = $curr_eg_release - 1;


# Species found on both vertebrates and non-vertebrates servers
my @overlap_species = qw(saccharomyces_cerevisiae drosophila_melanogaster caenorhabditis_elegans);

# --------------------------- CORE DATABASES -----------------------------------

# Use our mirror (which has all the databases)
#Bio::EnsEMBL::Registry->load_registry_from_url("mysql://ensro\@mysql-ens-vertannot-staging:4573/$curr_release");

# For previous releases, use the mirror servers
Bio::EnsEMBL::Registry->load_registry_from_url("mysql://ensro\@mysql-ens-mirror-1:4240/$curr_release");
# But remove the non-vertebrates species
Bio::EnsEMBL::Compara::Utils::Registry::remove_species(\@overlap_species);
Bio::EnsEMBL::Compara::Utils::Registry::remove_multi();
# And add the non-vertebrates server
Bio::EnsEMBL::Registry->load_registry_from_url("mysql://ensro\@mysql-ens-mirror-3:4275/$curr_release");

# ----------------------- COMPARA MASTER DATABASE ------------------------------

Bio::EnsEMBL::Compara::Utils::Registry::add_compara_dbas({
    'compara_master' => [ 'mysql-ens-compara-prod-10', 'ensembl_compara_master_citest' ],
});

# ------------------------------------------------------------------------------

1;
