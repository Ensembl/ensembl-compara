=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::Parts::ImportAltAlleGroupsAsHomologies

=head1 DESCRIPTION  

The PipeConfig file for the pipeline that imports alternative alleles as homologies.
This pipeline-part imports the alt-allele groups from the core databases,
to allow them to be displayed by the web code.

=head1 USAGE

=head2 eHive configuration

This pipeline assumes the param_stack is turned on. There is 1 job per species
and then 1 job per alt-allele group, so you will have to set 'import_altalleles_as_homologies_capacity'
not to overload the database.

Jobs take up to 500MB of memory and expect the patch_import and patch_import_himem
resource-classes to be defined.

=head2 Seeding

Seed a job in "offset_tables" or "altallele_species_factory". Its
parameters have to define a species-set. This can be done via a
"collection_name" parameter, a "mlss_id", etc. See GenomeDBFactory
for more details.

=head2 Global parameters

These parameters are required by several analyses and should probably
be declared as pipeline-wide.

=over

=item mafft_home

The home directory of the Mafft aligner

=back

=cut


package Bio::EnsEMBL::Compara::PipeConfig::Parts::ImportAltAlleGroupsAsHomologies;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Hive::PipeConfig::EnsemblGeneric_conf');


sub pipeline_analyses_alt_alleles {
    my ($self) = @_;
    return [

        {   -logic_name => 'offset_tables',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::OffsetTables',
            -parameters => {
                'range_index'   => 7,
            },
            -flow_into => [ 'altallele_species_factory' ],
        },

        {
            -logic_name => 'altallele_species_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
            -parameters => {
                'compara_db'    => '#member_db#',
            },
            -flow_into => {
                2   => [ 'altallegroup_factory' ],
            },
        },

        {
            -logic_name => 'altallegroup_factory',
            -module => 'Bio::EnsEMBL::Compara::RunnableDB::ObjectFactory',
            -parameters => {
                'compara_db'    => '#member_db#',
                'call_list'     => [ 'compara_dba', 'get_GenomeDBAdaptor', ['fetch_by_dbID', '#genome_db_id#'], 'db_adaptor', 'get_AltAlleleGroupAdaptor', 'fetch_all' ],
                'column_names2getters'  => { 'alt_allele_group_id' => 'dbID' },
            },
            -flow_into => {
                2 => [ 'import_altalleles_as_homologies' ],
            },
            -rc_name    => 'default_w_reg',
        },


        {   -logic_name => 'import_altalleles_as_homologies',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ImportAltAlleGroupAsHomologies',
            -hive_capacity => $self->o('import_altalleles_as_homologies_capacity'),
             -flow_into => {
                           -1 => [ 'import_altalleles_as_homologies_himem' ],  # MEMLIMIT
                           },
            -rc_name    => 'patch_import',
        },

        {   -logic_name => 'import_altalleles_as_homologies_himem',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ImportAltAlleGroupAsHomologies',
            -hive_capacity => $self->o('import_altalleles_as_homologies_capacity'),
            -rc_name    => 'patch_import_himem',
        },

    ];
}

1;


