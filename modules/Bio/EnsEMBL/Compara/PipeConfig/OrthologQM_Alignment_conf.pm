=pod

=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2019] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::PipeConfig::OrthologQM_Alignment_conf

=head1 SYNOPSIS

    To run on a species_set:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::OrthologQM_Alignment_conf -host mysql-ens-compara-prod-X -port XXXX \
            -member_type <protein_or_ncrna> -species_set_name <species_set_name>

        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::OrthologQM_Alignment_conf -host mysql-ens-compara-prod-X -port XXXX \
            -member_type <protein_or_ncrna> -species_set_id <species_set_dbID>

    To run on a pair of species:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::OrthologQM_Alignment_conf -host mysql-ens-compara-prod-X -port XXXX \
            -member_type <protein_or_ncrna> -species1 homo_sapiens -species2 gallus_gallus

=head1 DESCRIPTION

    This pipeline uses whole genome alignments to calculate the coverage of homologous pairs.
    The coverage is calculated on both exonic and intronic regions seperately and summarised using a quality_score calculation
    The average quality_score between both members of the homology will be written to the homology table (in compara_db option)

    http://www.ebi.ac.uk/seqdb/confluence/display/EnsCom/Quality+metrics+for+the+orthologs

    Additional options:
    -compara_db         database containing relevant data (this is where final scores will be written)
    -alt_aln_dbs        take alignment objects from different sources (arrayref of urls or aliases)
    -alt_homology_db    take homology objects from a different source
    -previous_rel_db    reuse scores from a previous release (requires homology_id_mapping files)

    Note: If you wish to use homologies from one database, but the alignments live in a different database,
    remember that final scores will be written to the homology table of the appointed compara_db. So, if you'd
    like the final scores written to the homology database, assign this as compara_db and use the alt_aln_dbs option
    to specify the location of the alignments. Likewise, if you want the scores written to the alignment-containing
    database, assign it as compara_db and use the alt_homology_db option.

=head1 EXAMPLES

    # scores go to homology db, alignments come from afar
    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::OrthologQM_Alignment_conf -host mysql-ens-compara-prod-1 -port 4485 \
        -compara_db compara_alias -alt_aln_dbs [mysql://ro_user@hosty_mchostface/alignments]

    # scores go to alignment db
    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::OrthologQM_Alignment_conf -host mysql-ens-compara-prod-1 -port 4485 \
        -compara_db mysql://user:pass@host/alignments -alt_homology_db homology_alias

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::OrthologQM_Alignment_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.4;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');


sub hive_meta_table {
    my ($self) = @_;
    return {
        %{$self->SUPER::hive_meta_table},       # here we inherit anything from the base class

        'hive_use_param_stack'  => 1,           # switch on the new param_stack mechanism
    };
}

sub default_pipeline_name {         # Instead of ortholog_qm_alignment
    my ($self) = @_;
    return $self->o('member_type') . '_orth_qm_wga';
}

sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

        'master_db'   => 'compara_master',
        # location of homology data. note: wga_score will be written here
        'compara_db'  => '#expr( (#member_type# eq "protein") ? "compara_ptrees" : "compara_nctrees" )expr#',
        # if alignments are not all present in compara_db, define alternative db locations
        'alt_aln_dbs' => [
            # list of databases with EPO or LASTZ data
            'compara_curr',
        ],

        'species1'         => undef,
        'species2'         => undef,
        'species_set_name' => undef,
        'species_set_id'   => undef,
        'ref_species'      => undef,

        # 'alt_aln_dbs'      => undef,
        'alt_aln_dbs'      => [ ],
        'alt_homology_db'  => undef,
        
        # homology_dumps_dir location should be changed to the homology pipeline's workdir if the pipelines are still in progress
        # (the files only get copied to 'homology_dumps_shared_dir' at the end of each pipeline)
        'homology_dumps_dir'        => $self->o('homology_dumps_shared_basedir') . '/' . $self->o('collection')    . '/' . $self->o('ensembl_release'), # where we read the homology dump files from
        'homology_dumps_shared_dir' => $self->o('homology_dumps_shared_basedir') . '/' . $self->o('collection')    . '/' . $self->o('ensembl_release'), # where we copy the final wga files to

        'wga_dumps_dir'      => $self->o('pipeline_dir'),
        'prev_wga_dumps_dir' => $self->o('homology_dumps_shared_basedir') . '/' . $self->o('collection')    . '/' . $self->o('prev_release'),

        'orth_batch_size'  => 10, # set how many orthologs should be flowed at a time
    };
}

=head2 pipeline_create_commands

	Description: create tables for writing data to

=cut

sub pipeline_create_commands {
	my $self = shift;

	return [
		@{ $self->SUPER::pipeline_create_commands },
		$self->db_cmd( 'CREATE TABLE ortholog_quality (
			homology_id              INT NOT NULL,
            genome_db_id             INT NOT NULL,
            alignment_mlss           INT NOT NULL,
            combined_exon_coverage   FLOAT(5,2) NOT NULL,
            combined_intron_coverage FLOAT(5,2) NOT NULL,
			quality_score            FLOAT(5,2) NOT NULL,
            exon_length              INT NOT NULL,
            intron_length            INT NOT NULL,
            INDEX (homology_id)
        )'),
	];
}

sub pipeline_wide_parameters {
    my ($self) = @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},          # here we inherit anything from the base class

        'ensembl_release'    => $self->o('ensembl_release'),
        'homology_dumps_dir' => $self->o('homology_dumps_dir'),
        'orth_batch_size'    => $self->o('orth_batch_size'),
        'member_type'        => $self->o('member_type'),

        'wga_dumps_dir'      => $self->o('wga_dumps_dir'),
        'prev_wga_dumps_dir' => $self->o('prev_wga_dumps_dir'),
        'previous_wga_file'  => defined $self->o('prev_wga_dumps_dir') ? '#prev_wga_dumps_dir#/#hashed_mlss_id#/#orth_mlss_id#.#member_type#.wga.tsv' : undef,

        'homology_dumps_shared_dir' => $self->o('homology_dumps_shared_dir'),
    };
}

sub pipeline_analyses {
    my ($self) = @_;
    return [
        {   -logic_name => 'pair_species',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::PairCollection',
            -flow_into  => {
                '2->B' => [ 'select_mlss' ],
                'B->1' => [ 'copy_compara_tables' ],
                '3'    => [ 'reset_mlss' ],
            },
            -input_ids => [{
                'species_set_name' => $self->o('species_set_name'),
                'species_set_id'   => $self->o('species_set_id'),
                'ref_species'      => $self->o('ref_species'),
                'species1'         => $self->o('species1'),
                'species2'         => $self->o('species2'),
                'compara_db'       => $self->o('compara_db'),
                'alt_aln_dbs'      => $self->o('alt_aln_dbs'),
                'master_db'        => $self->o('master_db'),
                'alt_homology_db'  => $self->o('alt_homology_db'),
            }],
        },

        {   -logic_name => 'reset_mlss',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
                'sql' => 'DELETE FROM ortholog_quality WHERE alignment_mlss = #aln_mlss_id#',
            },
            -analysis_capacity => 3,
        },

        {   -logic_name => 'select_mlss',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::SelectMLSS',
            -parameters => { 'current_release' => $self->o('ensembl_release') },
            -flow_into  => {
                1 => [ '?accu_name=alignment_mlsses&accu_address=[]&accu_input_variable=accu_dataflow' ],
                2 => [ '?accu_name=mlss_db_mapping&accu_address={mlss_id}&accu_input_variable=mlss_db' ],
            },
            -rc_name => '500Mb_job',
            -analysis_capacity => 50,
        },

        {   -logic_name => 'copy_compara_tables',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::PrepTableCopy',
            -parameters => {
                'copy_chunk_size' => 10,
                'program'         => $self->o('populate_new_database_exe'),
                'reg_conf'        => $self->o('reg_conf'),
                'master_db'       => $self->o('master_db'),
                'pipeline_db'     => $self->pipeline_url(),
            },
            -flow_into  => {
                '3->C' => [ 'copy_genomic_align_blocks', 'copy_mlss_tags' ],
                'C->2' => [ 'ortholog_mlss_factory' ]
            },
            -analysis_capacity => 1,
            -rc_name => '1Gb_job'

        },

        {   -logic_name => 'copy_genomic_align_blocks',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters    => {
                'where'       => 'method_link_species_set_id IN ( #expr( join( ",", @{ #mlss_id_list# } ) )expr# )',
                'table'       => 'genomic_align_block',
                'mode'        => 'topup',
             },
            -analysis_capacity => 1,
            -flow_into => { 1 => [ 'copy_genomic_aligns' ] },
        },

        {   -logic_name => 'copy_genomic_aligns',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters    => {
                'where'       => 'method_link_species_set_id IN ( #expr( join( ",", @{ #mlss_id_list# } ) )expr# )',
                'table'       => 'genomic_align',
                'mode'        => 'topup',
             },
            -analysis_capacity => 1,
        },

        {   -logic_name => 'copy_mlss_tags',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters    => {
                'where'       => 'method_link_species_set_id IN ( #expr( join( ",", @{ #mlss_id_list# } ) )expr# )',
                'table'       => 'method_link_species_set_tag',
                'mode'        => 'topup',
             },
            -analysis_capacity => 1,
        },

        {   -logic_name => 'ortholog_mlss_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::OrthologMLSSFactory',
            -flow_into  => {
                '2->A' => [ 'prepare_orthologs' ],
                'A->1' => [ 'check_file_copy' ],
            }
        },

        {   -logic_name => 'prepare_orthologs',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::PrepareOrthologs',
            -parameters => {
                'hashed_mlss_id'            => '#expr(dir_revhash(#orth_mlss_id#))expr#',
                'homology_flatfile'         => '#homology_dumps_dir#/#hashed_mlss_id#/#orth_mlss_id#.#member_type#.homologies.tsv',
                'homology_mapping_flatfile' => '#homology_dumps_dir#/#hashed_mlss_id#/#orth_mlss_id#.#member_type#.homology_id_map.tsv',
            },
            -analysis_capacity  =>  50,  # use per-analysis limiter
            -flow_into => {
                # these analyses will write to the same file, so a semaphore is required to prevent clashes
                '3->A' => [ 'reuse_wga_score' ],
                'A->2' => [ 'calculate_wga_coverage' ],
            },
            -rc_name  => '2Gb_job',
        },

        {   -logic_name => 'calculate_wga_coverage',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::CalculateWGACoverage',
            -hive_capacity => 30,
            -batch_size => 10,
            -parameters => { alignment_db => $self->pipeline_url },
            -flow_into  => {
                3 => [ '?table_name=ortholog_quality' ],
                2 => [ 'assign_wga_coverage_score' ],
            },
            -rc_name => '2Gb_job',
        },

        {   -logic_name => 'assign_wga_coverage_score',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::AssignQualityScore',
            -parameters => {
                'hashed_mlss_id' => '#expr(dir_revhash(#orth_mlss_id#))expr#',
                'output_file'    => '#wga_dumps_dir#/#hashed_mlss_id#/#orth_mlss_id#.#member_type#.wga.tsv',
                'reuse_file'     => '#wga_dumps_dir#/#hashed_mlss_id#/#orth_mlss_id#.#member_type#.wga_reuse.tsv',
            },
            -hive_capacity     => 400,
        },

        {   -logic_name => 'reuse_wga_score',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::ReuseWGAScore',
            -parameters => {
                'hashed_mlss_id'            => '#expr(dir_revhash(#orth_mlss_id#))expr#',
                'previous_wga_file'         => '#prev_wga_dumps_dir#/#hashed_mlss_id#/#orth_mlss_id#.#member_type#.wga.tsv',
                'homology_mapping_flatfile' => '#homology_dumps_dir#/#hashed_mlss_id#/#orth_mlss_id#.#member_type#.homology_id_map.tsv',
                'output_file'               => '#wga_dumps_dir#/#hashed_mlss_id#/#orth_mlss_id#.#member_type#.wga_reuse.tsv',
            },
            -hive_capacity     => 400,
        },

        {   -logic_name  => 'check_file_copy',
            -module      => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -flow_into   => WHEN( '#homology_dumps_shared_dir#' => 'copy_files_to_shared_loc' ),
        },

        {   -logic_name => 'copy_files_to_shared_loc',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters => {
                'shared_user'               => $self->o('shared_user'),
                'cmd'                       => 'become #shared_user# /bin/bash -c "mkdir -p #homology_dumps_shared_dir# && find #wga_dumps_dir#/ -name \'*.wga.tsv\' -exec cp {} #homology_dumps_shared_dir# \;"',
            },
        },

    ];
}

1;
