=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2020] EMBL-European Bioinformatics Institute

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


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::Legacy::EPO_pt3_conf

=head1 DESCRIPTION

    The PipeConfig file for the last part (3rd part) of the EPO pipeline. 
    This will genereate the multiple sequence alignments (MSA) from a database containing a
    set of anchor sequences mapped to a set of target genomes. The pipeline runs Enredo 
    (which generates a graph of the syntenic regions of the target genomes) 
    and then runs Ortheus (which runs Pecan for generating the MSA) and infers 
    ancestral genome sequences. Finally Gerp may be run to generate constrained elements and 
    conservation scores from the MSA.

=head1 SYNOPSIS

    #1. update ensembl-hive, ensembl and ensembl-compara GIT repositories before each new release

    #3. make sure that all default_options are set correctly

    #4. Run init_pipeline.pl script:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Legacy::EPO_pt3_conf -host mysql-ens-compara-prod-X -port XXXX \
            -division $COMPARA_DIV -species_set_name <species_set_name> -mlss_id <curr_epo_mlss_id> \
            -compara_mapped_anchor_db <db_alias_from_epo_pt2_pipeline> 

    #5. Sync and loop the beekeeper.pl as shown in init_pipeline.pl's output

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Legacy::EPO_pt3_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;           # Allow this particular config to use conditional dataflow

use Bio::EnsEMBL::Compara::PipeConfig::Parts::EPOAlignment;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');

sub default_options {
 my ($self) = @_;

    return {
        %{$self->SUPER::default_options},

        'pipeline_name' => $self->o('species_set_name').'_epo_'.$self->o('rel_with_suffix'),

        # 'mlss_id' => 647, # method_link_species_set_id of the ortheus alignments which will be generated

        'master_db'    => 'compara_master',
        'ancestral_db' => $self->o('species_set_name') . '_ancestral',

        'run_gerp' => 0,

        'enredo_params' => ' --min-score 0 --max-gap-length 200000 --max-path-dissimilarity 4 --min-length 10000 '.
    	'--min-regions 2 --min-anchors 3 --max-ratio 3 --simplify-graph 7 --bridges -o ',

        # Dump directory
        'dump_dir' => $self->o('pipeline_dir'),
        'enredo_output_file' => $self->o('dump_dir').'enredo_#mlss_id#.out',
        'bed_dir' => $self->o('dump_dir').'bed_dir',
        'output_dir' => $self->o('dump_dir').'feature_dumps',
        'enredo_mapping_file' => $self->o('dump_dir').'enredo_friendly.mlssid_#mlss_id#_'.$self->o('rel_with_suffix'),
        'bl2seq_dump_dir' => $self->o('dump_dir').'bl2seq', # location for dumping sequences to determine strand (for bl2seq)
        'bl2seq_file_stem' => $self->o('bl2seq_dump_dir')."/bl2seq",

        # add MT dnafrags separately (1) or not (0) to the dnafrag_region table
        'add_non_nuclear_alignments' => 1,

        'gerp_window_sizes'    => [1,10,100,500], #gerp window sizes
        'skip_multiplealigner_stats' => 0, #skip this module if set to 1

        'ancestral_sequences_name' => 'ancestral_sequences',
    }; 
}

sub pipeline_create_commands {
    my ($self) = @_; 
    return [
        @{$self->SUPER::pipeline_create_commands}, 
        $self->pipeline_create_commands_rm_mkdir(['dump_dir', 'bl2seq_dump_dir', 'output_dir', 'bed_dir']),
           ];  
}

sub pipeline_wide_parameters {
	my $self = shift @_;
	return {
		%{$self->SUPER::pipeline_wide_parameters},
                'ancestral_db' => $self->o('ancestral_db'),
		'enredo_mapping_file' => $self->o('enredo_mapping_file'),
		'master_db' => $self->o('master_db'),
		'compara_mapped_anchor_db' => $self->o('compara_mapped_anchor_db'),
		'work_dir' => $self->o('work_dir'),
		'mlss_id' => $self->o('mlss_id'),
		'enredo_output_file' => $self->o('enredo_output_file'),
                'run_gerp' => $self->o('run_gerp'),
                'genome_dumps_dir' => $self->o('genome_dumps_dir'),
	};
}

sub core_pipeline_analyses {
	my ($self) = @_;

        return [
            {   -logic_name => 'copy_table_factory',
                -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
                -parameters => {
                    'db_conn'      => '#compara_mapped_anchor_db#',
                    'inputlist'    => [ 'method_link', 'genome_db', 'species_set', 'species_set_header', 'method_link_species_set', 'dnafrag', 'ncbi_taxa_name', 'ncbi_taxa_node' ],
                    'column_names' => [ 'table' ],
                },
                -input_ids => [{}],
                -flow_into => {
                    '2->A' => { 'copy_table' => { 'src_db_conn' => '#db_conn#', 'table' => '#table#' } },
                    '1->A' => [ 'drop_ancestral_db', 'set_internal_ids' ],
                    'A->1' => [ 'copy_mlss' ],
                },
            },

            {   -logic_name    => 'copy_table',
                -module        => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
                -parameters    => {
                    'mode'          => 'topup',
                    'filter_cmd'    => 'sed "s/ENGINE=MyISAM/ENGINE=InnoDB/"',
                },
            },

            {   -logic_name    => 'copy_mlss',
                -module        => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
                -parameters    => {
                    'src_db_conn'   => '#master_db#',
                    'mode'          => 'topup',
                    'table'         => 'method_link_species_set',
                    'where'         => 'method_link_species_set_id = #mlss_id#',
                },
                -flow_into     => [ 'make_species_tree' ],
            },

            @{ Bio::EnsEMBL::Compara::PipeConfig::Parts::EPOAlignment::pipeline_analyses_epo_alignment($self) },
        ];
}

sub tweak_analyses {
    my $self = shift;
    my $analyses_by_name = shift;

    $analyses_by_name->{'dump_mappings_to_file'}->{'-parameters'}->{'db_conn'} = '#compara_mapped_anchor_db#';
}

1;
