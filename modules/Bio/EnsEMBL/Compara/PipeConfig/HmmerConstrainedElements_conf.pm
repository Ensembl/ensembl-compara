package Bio::EnsEMBL::Compara::PipeConfig::HmmerConstrainedElements_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');
use Data::Dumper;

sub default_options {
    my ($self) = @_; 

    return {
        'pipeline_name' => 'compara_hmmer_ces',
        'ensembl_cvs_root_dir' => $ENV{'ENSEMBL_CVS_ROOT_DIR'},
           # parameters that are likely to change from execution to another:
        'release'               => '82',
        'rel_suffix'            => '',    # an empty string by default, a letter otherwise
           # dependent parameters:
        'rel_with_suffix'       => $self->o('release').$self->o('rel_suffix'),
        'password'              => $ENV{'ENSADMIN_PSW'},
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
	'nhmmer' => '/software/ensembl/compara/hmmer3.1_alpha_0.20/src/nhmmer',
	'hmmbuild' => '/software/ensembl/compara/hmmer3.1_alpha_0.20/src/hmmbuild',
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

sub pipeline_create_commands {
    my ($self) = @_;
    return [
        @{$self->SUPER::pipeline_create_commands},  # inheriting database and hive tables' creation
           ];
}

sub resource_classes {
    my ($self) = @_; 
    return {
         0 => { -desc => 'default',  'LSF' => '' },
         1 => { -desc => 'mem3500',  'LSF' => '-C0 -M3500000 -R"select[mem>3500] rusage[mem=3500]"' },
         2 => { -desc => 'mem7500',  'LSF' => '-C0 -M7500000 -R"select[mem>7500] rusage[mem=7500]"' },  
         3 => { -desc => 'mem11400', 'LSF' => '-C0 -M11400000 -R"select[mem>11400] rusage[mem=11400]"' },  
         4 => { -desc => 'mem14000', 'LSF' => '-C0 -M14000000 -R"select[mem>14000] rusage[mem=14000]"' },  
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
# Turn all tables except 'genome_db' to InnoDB
            {   -logic_name => 'innodbise_table_factory',
                -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
                -parameters => {
                                'inputquery'      => "SELECT table_name FROM information_schema.tables WHERE table_schema ='" . 
                                                $self->o('pipeline_db','-dbname') .
                                                "' AND table_name!='genome_db' AND engine='MyISAM' ",
                                'fan_branch_code' => 2,
                               },  
                -input_ids => [{}],
                -flow_into => {
                               2 => [ 'innodbise_table' ],
                              },  
            },  
            {   -logic_name    => 'innodbise_table',
                -module        => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
                -parameters    => {
                                   'sql'         => "ALTER TABLE #table_name# ENGINE=InnoDB",
                                  },  
            }, 
	    {
		-logic_name    => 'drop_dnafrag_index_on_genomic_align',
		-module        => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
		-parameters    => {
					'sql' => "DROP INDEX dnafrag ON genomic_align",
				},
		-input_ids => [{}],
		-wait_for       => [ 'innodbise_table' ],
	   },
	   {
		-logic_name    => 'add_dnafrag_index_on_genomic_align',
		-module        => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
		-parameters    => {
					'sql' => "CREATE INDEX dnafrag_id_idx ON genomic_align (dnafrag_id)",
				},
		-input_ids => [{}],
		-wait_for       => [ 'drop_dnafrag_index_on_genomic_align' ],
	   },
	   {
		-logic_name    => 'split_constrained_element_ids',
		-module         => 'Bio::EnsEMBL::Compara::Production::EPOanchors::HMMer::SplitCeIds',
		-wait_for       => [ 'innodbise_table' ],
		-input_ids => [{}],
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
		-rc_id => 2,
		-wait_for => 'import_genome_dbs_and_dnafrags',
	   },
	   {   -logic_name      => 'load_cons_eles',
                -module         => 'Bio::EnsEMBL::Compara::Production::EPOanchors::HMMer::LoadConsEles',
		-wait_for       => [ 'dump_genome_repeats' ],
                -parameters     => {},
		-wait_for       => [ 'add_dnafrag_index_on_genomic_align' ],
		-hive_capacity  => 200,
           },
	   {
		-logic_name     => 'find_repeat_gabs',
		-module         => 'Bio::EnsEMBL::Compara::Production::EPOanchors::HMMer::FindRepeatGabs',
		-rc_id          => 2,
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
		-rc_id          => 3,
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
