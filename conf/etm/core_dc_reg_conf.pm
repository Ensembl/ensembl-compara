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

# ---------------------- CURRENT CORE DATABASES----------------------------------

# e116 core databases
Bio::EnsEMBL::Registry->load_registry_from_url('mysql://ensro@mysql-ens-compara-prod-1:4485/116');

# additional core databases
my $additional_cores = {
    'arabidopsis_thaliana_gca001651475v1gb' => [ 'mysql-ens-compara-prod-1', 'arabidopsis_thaliana_gca001651475v1gb_core_62_114_1' ],
    'arabidopsis_thaliana_gca978657495v1gb' => [ 'mysql-ens-compara-prod-1', 'arabidopsis_thaliana_gca978657495v1gb_core_114_1' ],
    'avena_sativa_gca022788535v1'           => [ 'mysql-ens-compara-prod-1', 'avena_sativa_gca022788535v1_core_110_1' ],
    'brassica_napus_gca905183035v1gb'       => [ 'mysql-ens-compara-prod-1', 'brassica_napus_gca905183035v1gb_core_62_114_1' ],
    'hordeum_vulgare'                       => [ 'mysql-ens-compara-prod-1', 'hordeum_vulgare_core_57_110_4' ],
    'hordeum_vulgare_gca949782835v1cm'      => [ 'mysql-ens-compara-prod-1', 'hordeum_vulgare_gca949782835v1cm_core_114_1' ],
    'oryza_sativa_gca001433935v1cm'         => [ 'mysql-ens-compara-prod-1', 'oryza_sativa_gca001433935v1cm_core_114_1' ],
    'oryza_sativa_gca009914875v1'           => [ 'mysql-ens-compara-prod-1', 'oryza_sativa_gca009914875v1_core_110_1' ],
    'solanum_lycopersicum_gca000188115v5cm' => [ 'mysql-ens-compara-prod-1', 'solanum_lycopersicum_gca000188115v5cm_core_114_1' ],
};
Bio::EnsEMBL::Compara::Utils::Registry::add_core_dbas( $additional_cores );

# -------------------------------------------------------------------

1;
