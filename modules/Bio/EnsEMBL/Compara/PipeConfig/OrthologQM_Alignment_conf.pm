=pod

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

use Bio::EnsEMBL::Hive::Version v2.4;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;
use Bio::EnsEMBL::Compara::PipeConfig::Parts::OrthologQMAlignment;

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
        'collection'       => 'default',

        'homology_method_link_types' => ['ENSEMBL_ORTHOLOGUES'],

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

sub no_compara_schema {}    # Tell the base class not to create the Compara tables in the database

=head2 pipeline_create_commands

	Description: create tables for writing data to

=cut

sub pipeline_create_commands {
	my $self = shift;

	return [
		@{ $self->SUPER::pipeline_create_commands },
		$self->db_cmd( 'CREATE TABLE ortholog_quality (
            homology_id              VARCHAR(40) NOT NULL,
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

        'gene_dumps_dir'     => $self->o('gene_dumps_dir'),

        'compara_db'         => $self->o('compara_db'),
        'master_db'          => $self->o('master_db'),
        'alt_aln_dbs'        => $self->o('alt_aln_dbs'),
        'alt_homology_db'   => $self->o('alt_homology_db'),

        'homology_dumps_shared_dir' => $self->o('homology_dumps_shared_dir'),
    };
}

sub pipeline_analyses {
    my ($self) = @_;
    return [
        {   -logic_name => 'fire_orth_wga',
            -input_ids  => [ {
                'species_set_name' => $self->o('species_set_name'),
                'species_set_id'   => $self->o('species_set_id'),
                'ref_species'      => $self->o('ref_species'),
                'species1'         => $self->o('species1'),
                'species2'         => $self->o('species2'),
            } ],
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -flow_into  => 'pair_species',
        },

        @{ Bio::EnsEMBL::Compara::PipeConfig::Parts::OrthologQMAlignment::pipeline_analyses_ortholog_qm_alignment($self) },
    ];
}

1;
