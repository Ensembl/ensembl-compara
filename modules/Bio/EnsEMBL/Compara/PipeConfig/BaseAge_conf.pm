=head1 LICENSE

See the NOTICE file distributed with this work for additional information
regarding copyright ownership.

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

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::BaseAge_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::BaseAge_conf -host mysql-ens-compara-prod-X -port XXXX \
        -ref_species homo_sapiens -species_set_name mammals -clade_taxon_id 9443 -compara_db compara_curr -division vertebrates \
        -variation_url mysql://ensro@mysql-ens-sta-1:4519/homo_sapiens_variation_${CURR_ENSEMBL_RELEASE}_38?group=variation

=head1 DESCRIPTION

    Calculate the age of a base.

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::BaseAge_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.4;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;   # For INPUT_PLUS

use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');

sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},

            'pipeline_name' => $self->o('ref_species').'_base_age_'.$self->o('rel_with_suffix'), # name used by the beekeeper to prefix job names on the farm

            #Write either the node name or node_id in "name" field of the bed file
#            'name' => "node_id",
            'name' => "name",

            # Location url/alias of database to get EPO GenomicAlignTree objects from
            'compara_db'   => 'compara_curr',
            'ancestral_db' => 'ancestral_curr',    # You may set this to undef if compara_db is a database that contains genome_db locators

            # The name of the alignment
            'species_set_name' => undef,

            # There is a different colour gradient for this clade
            'clade_taxon_id' => undef,

            'baseage_autosql' => $self->check_file_in_ensembl('ensembl-compara/scripts/pipeline/baseage_autosql.as'),

            #Locations to write output files
            'bed_dir'        => $self->o('pipeline_dir'),
            'chr_sizes_file' => 'chrom.sizes',
            'big_bed_file'   => 'base_age'.$self->o('rel_with_suffix').'.bb',

            # Number of workers to run base_age analysis
            'base_age_capacity'        => 100,
          };
}

sub no_compara_schema {}    # Tell the base class not to create the Compara tables in the database

sub pipeline_create_commands {
    my ($self) = @_;
    return [
        @{$self->SUPER::pipeline_create_commands},  # inheriting database and hive tables' creation

            $self->pipeline_create_commands_rm_mkdir('bed_dir'),

	   ];
}

sub pipeline_analyses {
    my ($self) = @_;

    return [
            { -logic_name => 'chrom_sizes',
              -module     => 'Bio::EnsEMBL::Hive::RunnableDB::DbCmd',
              -parameters => {
                              'db_conn' => $self->o('compara_db'),
                              'bed_dir' => $self->o('bed_dir'),
                              'append'  => [qw(-N -q)],
                              'input_query' => "SELECT dnafrag.name, length FROM dnafrag JOIN genome_db USING (genome_db_id) WHERE genome_db.name = '" . $self->o('ref_species') . "'" . " AND is_reference = 1",
                              'chr_sizes_file' => $self->o('chr_sizes_file'),
                              'output_file' => "#bed_dir#/#chr_sizes_file#",
                             },
               -input_ids => [{}],
              -flow_into => {
                             '1' => [ 'base_age_factory' ],
                            },
           },

            {  -logic_name => 'base_age_factory',
               -module     => 'Bio::EnsEMBL::Compara::RunnableDB::DnaFragFactory',
               -parameters => {
                               'compara_db'     => $self->o('compara_db'),
                               'genome_db_name' => $self->o('ref_species'),
                               'only_karyotype' => 1,
                               'extra_parameters'  => [ 'name' ],
                              },
               -flow_into => {
                              '2->A' => { 'base_age' => { 'seq_region' => '#name#', }, },
                              'A->1' => [ 'base_age_funnel_check' ],
                             },
            },
            
            { -logic_name => 'base_age',
              -module     => 'Bio::EnsEMBL::Compara::RunnableDB::BaseAge::BaseAge',
              -parameters => {
                              'compara_db' => $self->o('compara_db'),
                              'ancestral_db' => $self->o('ancestral_db'),
                              'species_set_name' => $self->o('species_set_name'),
                              'species' => $self->o('ref_species'),
                              'bed_dir' => $self->o('bed_dir'),
                              'name' => $self->o('name'),
                              'clade_taxon_id' => $self->o('clade_taxon_id'),
                             },
              -batch_size => 1,
              -hive_capacity => $self->o('base_age_capacity'),
              -rc_name => '4Gb_24_hour_job',
              -flow_into => {
                  2 => { 'sort_bed' => INPUT_PLUS(), },
              },
            },

            {   -logic_name => 'sort_bed',
                -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
                -parameters => {
                    'sorted_bed_file'   => '#bed_file#.sort',
                    'cmd'               => 'sort -k2,2n #bed_file# > #sorted_bed_file#',
                },
                -rc_name    => '16Gb_job',
                -flow_into  => {
                    1 => '?accu_name=bed_files&accu_address={seq_region}&accu_input_variable=sorted_bed_file',
                },
            },

            {   -logic_name => 'base_age_funnel_check',
                -module     => 'Bio::EnsEMBL::Compara::RunnableDB::FunnelCheck',
                -flow_into  => { 1 => { 'big_bed' => INPUT_PLUS() } },
            },

             { -logic_name => 'big_bed',
               -module     => 'Bio::EnsEMBL::Compara::RunnableDB::BaseAge::BigBed',
               -parameters => {
                               'program' => $self->o('big_bed_exe'),
                              'baseage_autosql' => $self->o('baseage_autosql'),
                               'big_bed_file' => '#bed_dir#/'.$self->o('big_bed_file'),
                               'bed_dir' => $self->o('bed_dir'),
                               'chr_sizes_file' => $self->o('chr_sizes_file'),
                               'chr_sizes' => '#bed_dir#/#chr_sizes_file#',
                              },
               -rc_name => '16Gb_24_hour_job',
             },

     ];
}
1;
