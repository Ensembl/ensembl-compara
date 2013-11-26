#!/usr/bin/env perl
# Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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


# Generates a list of Bio::EnsEMBL::DBSQL::DBAdaptor objects for all core databases found on two staging servers
# minus databases that contain ancestral sequences.

use strict;
use warnings;

use Bio::EnsEMBL::Registry;

Bio::EnsEMBL::Registry->load_registry_from_multiple_dbs(
    {   '-host' => 'ens-staging.internal.sanger.ac.uk',
        '-port' => 3306,
        '-user' => 'ensro',
        '-pass' => '',
    },
    {   '-host' => 'ens-staging2.internal.sanger.ac.uk',
        '-port' => 3306,
        '-user' => 'ensro',
        '-pass' => '',
    },
);

my @core_dbas = grep { $_->species !~ /ancestral/i } @{ Bio::EnsEMBL::Registry->get_all_DBAdaptors( -group => 'core') };

print "\n------------[Found a total of ".scalar(@core_dbas)."core databases on staging servers]------------\n";
foreach my $dba (@core_dbas) {
    print 'dba_species: '.$dba->species()."\n";
}

