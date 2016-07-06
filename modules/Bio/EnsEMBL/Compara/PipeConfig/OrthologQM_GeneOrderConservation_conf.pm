=pod
=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016] EMBL-European Bioinformatics Institute

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
	
	Bio::EnsEMBL::Compara::PipeConfig::OrthologQM_GeneOrderConservation_conf;

=head1 DESCRIPTION
    if a default threshold is not given the pipeline will use the genetic distance between the pair species to choose between a threshold of 50 and 75 percent.
	http://www.ebi.ac.uk/seqdb/confluence/display/EnsCom/Quality+metrics+for+the+orthologs


    Example run
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::OrthologQM_GeneOrderConservation_conf -goc_mlss_id <20620> -goc_threshold (optional) -pipeline_name <GConserve_trial> -host <host_server>

=cut


package Bio::EnsEMBL::Compara::PipeConfig::OrthologQM_GeneOrderConservation_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;  

sub hive_meta_table {
    my ($self) = @_;
    return {
        %{$self->SUPER::hive_meta_table},       # here we inherit anything from the base class

        'hive_use_param_stack'  => 1,           # switch on the new param_stack mechanism
    };
}


sub default_options {
    my $self = shift;
    return {
            %{ $self->SUPER::default_options() },

        'goc_mlss_id'     => undef, #'100021',
        'compara_db' => undef, #'mysql://ensadmin:'.$ENV{ENSADMIN_PSW}.'@compara2/wa2_protein_trees_snapshot_84'
#        'compara_db' => 'mysql://ensro@compara4/OrthologQM_test_db'
        'goc_threshold' => undef,
    };
}

sub pipeline_wide_parameters {
    my ($self) = @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},          # here we inherit anything from the base class
        'goc_mlss_id' => $self->o('goc_mlss_id'),
        'compara_db' => $self->o('compara_db'),
        'goc_threshold'  => $self->o('goc_threshold'),
    };
}

sub resource_classes {
    my ($self) = @_;
    return {
        %{$self->SUPER::resource_classes},  # inherit 'default' from the parent class
        '2Gb_job'      => {'LSF' => '-C0 -M2000  -R"select[mem>2000]  rusage[mem=2000]"' },
        '16Gb_job'      => {'LSF' => '-C0 -M16000  -R"select[mem>16000]  rusage[mem=16000]"' },
    };
}


sub pipeline_analyses {
    my ($self) = @_;
    return [
        {   -logic_name => 'get_orthologs',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::OrthologFactory',
            -input_ids => [ { } ],
#            -parameters     => {'compara_db' => 'mysql://ensro@compara1/mm14_protein_trees_82'},
            -flow_into => {
                '2->A' => { 'create_ordered_chr_based_job_arrays' => INPUT_PLUS },
                'A->1' => { 'get_max_orth_percent' => INPUT_PLUS },       
            },
            -hive_capacity  =>  200,  # use per-analysis limiter
            -rc_name => '2Gb_job',
        },

        {	-logic_name	=>	'create_ordered_chr_based_job_arrays',
        	-module		=>	'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Prepare_Per_Chr_Jobs',
        	-analysis_capacity  =>  50,
			-flow_into	=>	{
				2	=>	['check_ortholog_neighbors'],
			},
			-rc_name => '2Gb_job',
        },

        {
        	-logic_name	=>	'check_ortholog_neighbors',
        	-module	=>	'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Compare_orthologs',
#            -parameters     => {'compara_db' => 'mysql://ensro@compara1/mm14_protein_trees_82'},
            -analysis_capacity  =>  50,
        	-flow_into	=> {
                2 => [ $self->o('compara_db').'/ortholog_goc_metric' ],
#        		2 => [ ':////ortholog_goc_metric' ],
        	},

 #           -rc_name => '2Gb_job',
        },

        {
            -logic_name => 'get_max_orth_percent',
            -module => 'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Ortholog_max_score',
            -flow_into => {
                1 => WHEN( 'defined #goc_threshold#' => [ 'get_perc_above_threshold'  ] ,
                    ELSE [ 'get_genetic_distance' ] ),
            },
            -rc_name => '16Gb_job',
        },

        {
            -logic_name => 'get_genetic_distance',
            -module => 'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Fetch_genetic_distance',
            -flow_into => {
                1 =>    ['threshold_calculator'],
                },
        },

        {
            -logic_name => 'threshold_calculator',
            -module => 'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Calculate_goc_threshold',
            -flow_into => {
                1 =>    ['get_perc_above_threshold'],
                },
        },

        {
            -logic_name => 'get_perc_above_threshold',
            -module => 'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Calculate_goc_perc_above_threshold',
            -flow_into => {
                1 =>    ['store_goc_dist_asTags'],
                },
        },

        {
            -logic_name => 'store_goc_dist_asTags',
            -module 	=> 'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::StoreGocStatsAsMlssTags',
#            -parameters =>	{'compara_db' => $self->o('compara_db') },
        },

        
    ];
}

1;
