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

package Bio::EnsEMBL::Compara::PipeConfig::Legacy::HmmerConstrainedElements_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');
use Data::Dumper;

sub default_options {
    my ($self) = @_; 

    return {
        %{$self->SUPER::default_options},

        'pipeline_name' => 'compara_hmmer_ces',

           # connection parameters to various databases:
        'pipeline_db' => { # the production database itself (will be created)
                -host   => 'compara1',
                -port   => 3306,
                -user   => 'ensadmin',
                -pass   => $self->o('password'),
                -dbname => $ENV{'USER'}.'_hmmer_constrained_elements'.$self->o('rel_with_suffix'),
        },
	   # database containing the constrained elements
        'compara_db' => {
                -user => 'ensro',
                -port => 3306,
                -host => 'compara1',
                -pass => '',
                -dbname => 'sf5_ensembl_compara_62',
        },
	# hmmer software location
	'find_overlaps' => '~jh7/bin/find_overlapping_features.pl',
      'nhmmer' => '/software/ensembl/compara/hmmer-3.1b1/binaries/nhmmer',
      'hmmbuild' => '/software/ensembl/compara/hmmer-3.1b1/binaries/hmmbuild',
	'target_genome' => {'name' => 'homo_sapiens', 'genome_seq' => '/data/blastdb/Ensembl/compara12way63/homo_sapiens/genome_seq'},
	  # minimum constrained element size to use
	'min_constrained_element_length' => 20,
	'mlssid_of_constrained_elements' => 519,
	'mlssid_of_alignments' => 518, 
	'ce_batch_size' => 100,
	'high_coverage_species' => ["rattus_norvegicus","macaca_mulatta","pan_troglodytes","canis_familiaris","mus_musculus","pongo_abelii","equus_caballus","bos_taurus","homo_sapiens","sus_scrofa","gorilla_gorilla","callithrix_jacchus"],
	'repeat_dump_dir' => '/data/blastdb/Ensembl/compara_repeats',
	'core_db_url' => 'mysql://ensro@ens-livemirror:3306/62',
    };
}


sub resource_classes {
    my ($self) = @_; 
    return {
         'mem7500'  => { 'LSF' => '-C0 -M7500000 -R"select[mem>7500] rusage[mem=7500]"' },
         'mem11400' => { 'LSF' => '-C0 -M11400000 -R"select[mem>11400] rusage[mem=11400]"' },
    };  
}


sub pipeline_wide_parameters {
        my $self = shift @_;
        return {
                %{$self->SUPER::pipeline_wide_parameters},

                'compara_db' => $self->o('compara_db'),
		'mlssid_of_alignments' => $self->o('mlssid_of_alignments'),
		'mlssid_of_constrained_elements' => $self->o('mlssid_of_constrained_elements'),
		'high_coverage_species' => $self->o('high_coverage_species'),
		'repeat_dump_dir' => $self->o('repeat_dump_dir'),
		'core_db_url' => $self->o('core_db_url'),
		'find_overlaps' => $self->o('find_overlaps'),
		'target_genome' => $self->o('target_genome'),
        };

}


sub pipeline_analyses {
        my ($self) = @_;
        print "pipeline_analyses\n";

    return [
	    {
		-logic_name    => 'drop_dnafrag_index_on_genomic_align',
		-module        => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
		-parameters    => {
					'sql' => "DROP INDEX dnafrag ON genomic_align",
				},
                -flow_into     => [ 'add_dnafrag_index_on_genomic_align' ],
	   },
	   {
		-logic_name    => 'add_dnafrag_index_on_genomic_align',
		-module        => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
		-parameters    => {
					'sql' => "CREATE INDEX dnafrag_id_idx ON genomic_align (dnafrag_id)",
				},
                -flow_into     => [ 'split_constrained_element_ids' ],
	   },
	   {
		-logic_name    => 'split_constrained_element_ids',
		-module         => 'Bio::EnsEMBL::Compara::Production::EPOanchors::HMMer::SplitCeIds',
		-parameters     => {ce_batch_size => $self->o('ce_batch_size'),},
		-flow_into      => {
					1 => 'load_cons_eles',
					2 => 'dump_genome_repeats',
					3 => 'import_genome_dbs_and_dnafrags',
					4 => 'find_repeat_gabs',
				   },
	   },
	   {
		-logic_name    => 'import_genome_dbs_and_dnafrags',
		-module     => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
		-parameters => {
				'src_db_conn'   => $self->o('compara_db'),
				'where'         => 'genome_db_id IN (#genome_dbs_csv#)',
				},
		-hive_capacity  => 2,
	   },
	   {
		-logic_name    => 'dump_genome_repeats',
		-module        => 'Bio::EnsEMBL::Compara::Production::EPOanchors::HMMer::DumpRepeats',
		-hive_capacity  => 20,	
		-rc_name        => 'mem7500',
		-wait_for => 'import_genome_dbs_and_dnafrags',
	   },
	   {   -logic_name      => 'load_cons_eles',
                -module         => 'Bio::EnsEMBL::Compara::Production::EPOanchors::HMMer::LoadConsEles',
		-wait_for       => [ 'dump_genome_repeats' ],
                -parameters     => {},
		-hive_capacity  => 200,
           },
	   {
		-logic_name     => 'find_repeat_gabs',
		-module         => 'Bio::EnsEMBL::Compara::Production::EPOanchors::HMMer::FindRepeatGabs',
		-rc_name        => 'mem7500',
		-wait_for       => [ 'load_cons_eles' ],
		-hive_capacity  => 20,
	  },
	  {
		-logic_name     => 'load_gabs_to_search',
		-module        => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
		-input_ids => [{}],
                -parameters    => {
                                   'inputquery' => "SELECT genomic_align_block_id gab_id FROM genomic_align_block WHERE score IS NULL",
                                  },  
		-wait_for       => [ 'find_repeat_gabs', ],
		-rc_name        => 'mem11400',
		-flow_into	=> {
			2 => [ 'hmm_search' ],
		},
	  },
	  {
		-logic_name     => 'hmm_search',
		-module         => 'Bio::EnsEMBL::Compara::Production::EPOanchors::HMMer::HMMsearch',
		-hive_capacity  => 200,
		-parameters => {
				'target_genome' => $self->o('target_genome'),
				'nhmmer'        => $self->o('nhmmer'),
				'hmmbuild'      => $self->o('hmmbuild'),
		},
		-hive_capacity  => 200,
	  },
		
	];
}

1;
