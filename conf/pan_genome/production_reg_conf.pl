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

use Bio::EnsEMBL::Compara::Utils::Registry;

# ---------------------------- CORE DATABASES ----------------------------------

my $pan_genome_cores = {
    'homo_sapiens_GRCh38' => [ 'mysql-ens-genebuild-prod-1', 'kbillis_homo_sapiens_core_100_38_pan' ],
    'homo_sapiens_CHR13'  => [ 'mysql-ens-genebuild-prod-1', 'kbillis_humans_compara_master_CHR13_1' ],
};
Bio::EnsEMBL::Compara::Utils::Registry::add_core_dbas( $pan_genome_cores );

# --------------------------- COMPARA DATABASES --------------------------------

# FORMAT: species/alias name => [ host, db_name ]
my $compara_dbs = {
    # General compara dbs
    'compara_master' => [ 'mysql-ens-genebuild-prod-1', 'kbillis_human_cmp_CHM13_master' ],

    # 'compara_lastz'  => [ 'mysql-ens-genebuild-prod-1', '' ],

    # 'compara_syntenies' => [ 'mysql-ens-genebuild-prod-1', '' ],
};

Bio::EnsEMBL::Compara::Utils::Registry::add_compara_dbas( $compara_dbs );

# ------------------------- NON-COMPARA DATABASES ------------------------------

Bio::EnsEMBL::Compara::Utils::Registry::add_taxonomy_dbas({
    'ncbi_taxonomy' => [ 'mysql-ens-sta-1', "ncbi_taxonomy_$curr_release" ],
});

# ------------------------------------------------------------------------------

1;
