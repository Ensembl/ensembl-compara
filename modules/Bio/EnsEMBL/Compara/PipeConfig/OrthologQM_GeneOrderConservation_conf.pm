=pod

=head1 NAME
	
	Bio::EnsEMBL::Compara::PipeConfig::OrthologQM_GeneOrderConservation_conf;

=head1 DESCRIPTION

	http://www.ebi.ac.uk/seqdb/confluence/display/EnsCom/Quality+metrics+for+the+orthologs


    Example run
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::OrthologQM_GeneOrderConservation_conf -mlss_id <20620> -pipeline_name <GConserve_trial> -host <host_server>

=cut


package Bio::EnsEMBL::Compara::PipeConfig::OrthologQM_GeneOrderConservation_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');

sub hive_meta_table {
    my ($self) = @_;
    return {
        %{$self->SUPER::hive_meta_table},       # here we inherit anything from the base class

        'hive_use_param_stack'  => 1,           # switch on the new param_stack mechanism
    };
}


=head2 pipeline_create_commands 
	
	Description: create tables for writing data to

=cut

sub pipeline_create_commands {
	my $self = shift;

	#!!! NOTE: replace column names with desired col names for report.
	#          must be a param name!

	#PRIMARY KEY (genomic_align_block_id))'

	return [
		@{ $self->SUPER::pipeline_create_commands },
		$self->db_cmd( 'CREATE TABLE ortholog_quality_metric ( 
            method_link_species_set_id INT NOT NULL,
			homology_id INT NOT NULL,
            gene_member_id INT NOT NULL,
		    dnafrag_id INT NOT NULL,
			percent_conserved_score INT NOT NULL, 
            left1 INT,
         	left2 INT,
         	right1 INT,
         	right2 INT
            
        )'),

        $self->db_cmd( 'CREATE TABLE ortholog_metric ( 
            method_link_species_set_id INT NOT NULL, 
            homology_id INT NOT NULL,
            percent_conserved_score INT NOT NULL 
            
            
        )'),

    ];
}
      




sub default_options {
    my $self = shift;
    return {
            %{ $self->SUPER::default_options() },

        'mlss_id'     => '100021',
        'compara_db' => 'mysql://ensro@compara1/mm14_protein_trees_82'
#        'compara_db' => 'mysql://ensro@compara4/OrthologQM_test_db'
    };
}

sub pipeline_wide_parameters {
    my ($self) = @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},          # here we inherit anything from the base class
        'mlss_id' => $self->o('mlss_id'),
        'compara_db' => $self->o('compara_db'),
    };
}

sub resource_classes {
    my ($self) = @_;
    return {
        %{$self->SUPER::resource_classes},  # inherit 'default' from the parent class
        'default'      => {'LSF' => '-C0 -M100   -R"select[mem>100]   rusage[mem=100]"' },
        '2Gb_job'      => {'LSF' => '-C0 -M2000  -R"select[mem>2000]  rusage[mem=2000]"' },
        '20Gb_job'      => {'LSF' => '-C0 -M20000  -R"select[mem>20000]  rusage[mem=20000]"' },
    };
}


sub pipeline_analyses {
    my ($self) = @_;
    return [
        {   -logic_name => 'get_orthologs',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::OrthologFactory',
            -input_ids => [ { } ],
#            -parameters     => {'compara_db' => 'mysql://ensro@compara1/mm14_protein_trees_82'},
#            -analysis_capacity  =>  10,  # use per-analysis limiter
            -flow_into => {
                '2->A' => [ 'create_ordered_chr_based_job_arrays' ],
                'A->1' => [ 'get_max_orth_percent' ],       
            },
            -rc_name => '2Gb_job',
        },

#        {	-logic_name => 'prepare_orthologs',
#            -module => 'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM_new::Prepare_Orthologs',
#            -flow_into  =>  {
#                2   =>  [ 'create_ordered_chr_based_job_arrays' ],
#            },
#            -rc_name => '2Gb_job',
#        },

        {	-logic_name	=>	'create_ordered_chr_based_job_arrays',
        	-module		=>	'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Prepare_Per_Chr_Jobs',
#        	-analysis_capacity  =>  10,
			-flow_into	=>	{
				2	=>	['create_comparison_job_arrays'],
			},
			-rc_name => '2Gb_job',
        },
        {
        	-logic_name	=>	'create_comparison_job_arrays',
        	-module		=>	'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Comparison_job_arrays',
#            -analysis_capacity  =>  10,
        	-flow_into	=>	{
        		2 	=>	['check_ortholog_neighbors'],
        	},
#        	-rc_name => '2Gb_job',
        },
        {
        	-logic_name	=>	'check_ortholog_neighbors',
        	-module	=>	'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Compare_orthologs',
#            -input_ids => [ {'species1' => $self->o('species1')} ],
#            -parameters     => {'compara_db' => 'mysql://ensro@compara1/mm14_protein_trees_82'},
            -analysis_capacity  =>  50,
        	-flow_into	=> {
        		2 => [ ':////ortholog_quality_metric' ],
        	},

 #           -rc_name => '2Gb_job',
        },

        {
            -logic_name => 'get_max_orth_percent',
            -module => 'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Ortholog_max_score',
            -flow_into => {
                2 => [ ':////ortholog_metric' ],
            },
            -rc_name => '2Gb_job',
        },
    ];
}

1;












