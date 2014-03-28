=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Compara::PipeConfig::BuildHMMprofiles_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');

use Bio::EnsEMBL::ApiVersion qw/software_version/;

sub default_options {
    my ($self) = @_;

    return {
    # inherit other stuff from the base class
        %{ $self->SUPER::default_options() },
		'fasta_file' 	=> '/nfs/nobackup2/ensemblgenomes/ckong/workspace/buildhmmprofiles/archive_seq/PLANTS_HMM2_non_annot_members_EG20_PANTHER_8_1_SF.fa',
        'division'		=> 'PLANTS_HMM2_EG20_8_1_SF',
        'release'  		=> software_version(),
        'pipeline_name' => 'BuildHMMprofiles_'.$self->o('release').'_'.$self->o('division'),
        'email' 		=> $self->o('ENV', 'USER').'@ebi.ac.uk', 
	    'exe_dir'       => '/nfs/panda/ensemblgenomes/production/compara/binaries',
        'output_dir'    => '/nfs/nobackup2/ensemblgenomes/'.$self->o('ENV', 'USER').'/workspace/buildhmmprofiles/'.$self->o('division'),            
        'hmmLib_dir'    => $self->o('output_dir').'/hmmLib',    
        'msa_dir'    	=> $self->o('output_dir').'/msa',    

    # hive_capacity values for some analyses:
       'hmmbuild_capacity'	   => 100,
       'hmmcalibrate_capacity' => 100,
       'blastp_capacity'	   => 800, # 800 tested without problems of mysql connections
       'mcoffee_capacity'      => 600,
 
    # blast parameters:
       'blast_options'  => '-filter none -span1 -postsw -V=20 -B=20 -sort_by_highscore -warnings -cpus 1',
       'blast_tmp_dir'	=> $self->o('output_dir').'/blastTmp',

    # clustering parameters:
        'outgroups'                     => [127],   # affects 'hcluster_dump_input_per_genome'
        'clustering_max_gene_halfcount' => 750,     # (half of the previously used 'clutering_max_gene_count=1500) affects 'hcluster_run'

    # tree building parameters:
#        'treebreak_gene_count'      => 400,     # affects msa_chooser
#        'mafft_gene_count'          => 200,     # affects msa_chooser
#        'mafft_runtime'             => 7200,    # affects msa_chooser
        'use_exon_boundaries'	=> 0,       # affects 'mcoffee' and 'mcoffee_himem'

    # executable locations:
	    'wublastp_exe'	  =>  $self->o('exe_dir').'/wublast/blastp',
	    'hcluster_exe'    =>  $self->o('exe_dir').'/hcluster_sg',
	    'mcoffee_exe'     =>  $self->o('exe_dir').'/t_coffee',
	    'mafft_exe'       =>  $self->o('exe_dir').'/mafft-distro/bin/mafft',
	    'mafft_binaries'  =>  $self->o('exe_dir').'/mafft-distro/bin/mafft',
	    'mafft_home'      =>  $self->o('exe_dir').'/mafft-distro',
	    'xdformat_exe'	  =>  $self->o('exe_dir').'/wublast/xdformat',
	    'hmmbuild_exe'    =>  $self->o('exe_dir').'/hmmbuild_2', # for HMMer2 to use with PantherScore.pl  else hmmbuild => HMMer3
	    'hmmcalibrate'    =>  $self->o('exe_dir').'/hmmcalibrate',
    };
}

sub pipeline_create_commands {
    my ($self) = @_;
    return [
      # inheriting database and hive tables' creation
      @{$self->SUPER::pipeline_create_commands},
    ];
}

## See diagram for pipeline structure
sub pipeline_analyses {
    my ($self) = @_;
 
    return [
# ---------------------------------------------[blast step]---------------------------------------------------------------------
      { -logic_name    => 'backbone_fire_buildhmmprofiles',
        -module        => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
        -input_ids     => [ {} ], # Needed to create jobs
        -flow_into 	   => {
           	'1->A' => ['CreateBlastDB','paf_create_table'],
            'A->1' => ['PrepareSequence'],
        },
      },
      
      # Creating blastp jobs for each sequence
	  {  -logic_name => 'PrepareSequence',
         -module     => 'Bio::EnsEMBL::Compara::RunnableDB::BuildHMMprofiles::PrepareSequence',
         #-module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::PrepareSequence',
         -parameters => {
	        'fasta_file'        => $self->o('fasta_file'),
            'fan_branch_code'   => 2,
          },
         -flow_into  => {
                '2->A'	 => ['BlastpWithFasta'],
  		  		'A->1' 	 => ['hcluster_factory'],
         },
      },

      { -logic_name => 'CreateBlastDB',
        -module     => 'Bio::EnsEMBL::Compara::RunnableDB::BuildHMMprofiles::CreateBlastDB',
	    #-module     => 'Bio::EnsEMBL::Compara::RunnableDB::CreateBlastDB',
        -parameters => {
          'fasta_file'    => $self->o('fasta_file'),
          'xdformat_exe'  => $self->o('xdformat_exe'),
          'output_dir'    => $self->o('output_dir'),
        },
      },
      
     # Creating peptide_align_feature table to store blast output
     { -logic_name => 'paf_create_table',
       -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
       -parameters => {
        	'sql' => [  'CREATE TABLE IF NOT EXISTS `peptide_align_feature` 
        				 (`peptide_align_feature_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
        				  `qmember_id` mediumtext NOT NULL,
						  `hmember_id` mediumtext NOT NULL,
						  `qgenome_db_id` int(10) unsigned NOT NULL,
						  `hgenome_db_id` int(10) unsigned NOT NULL,
						  `qstart` int(10) NOT NULL DEFAULT \'0\',
						  `qend` int(10) NOT NULL DEFAULT \'0\',
						  `hstart` int(11) NOT NULL DEFAULT \'0\',
						  `hend` int(11) NOT NULL DEFAULT \'0\',
						  `score` int(5) NOT NULL DEFAULT \'0\',
						  `evalue` double DEFAULT NULL,
						  `align_length` int(10) DEFAULT NULL,
						  `identical_matches` int(10) DEFAULT NULL,
						  `perc_ident` int(10) DEFAULT NULL,
						  `positive_matches` int(10) DEFAULT NULL,
						  `perc_pos` int(10) DEFAULT NULL,
						  `hit_rank` int(10) DEFAULT NULL,
						  `cigar_line` mediumtext,
        	              PRIMARY KEY (`peptide_align_feature_id`) 
        	 			  )',
        	         ],     
           # `score` double(16,4) NOT NULL DEFAULT \'0.0000\',
           #KEY `hmember_hit` (`hmember_id`,`hit_rank`)
           #ENGINE=InnoDB DEFAULT CHARSET=latin1 MAX_ROWS=300000000 AVG_ROW_LENGTH=133,        			          
       },
       -batch_size     =>  100,  # they can be really, really short
     },

     # Perform blastp of each sequence against blastDB
	 {   -logic_name => 'BlastpWithFasta',
         -module     => 'Bio::EnsEMBL::Compara::RunnableDB::BuildHMMprofiles::BlastpWithFasta',
         #-module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::BlastpWithFasta',
         -parameters => {
	        'wublastp_exe'	=> $self->o('wublastp_exe'),
	        'output_dir'    => $self->o('output_dir'), # Need this to point to BLASTDB
	        'blast_options'	=> $self->o('blast_options'),
	        'blast_tmp_dir'	=> $self->o('blast_tmp_dir'),
     	},
        -hive_capacity => $self->o('blastp_capacity'),
        -batch_size    =>  50, 
        -rc_name       => 'default',
    },

# ---------------------------------------------[clustering step]---------------------------------------------------------------------
    {   -logic_name    => 'hcluster_factory',
        -module        => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
        -flow_into 	   => {
           	'1->A' => { 
          	#   		'hcluster_merge_inputs' => [{'ext' => 'txt'}, {'ext' => 'cat'}],
                   		'hcluster_prepare_input' => [{'ext' => 'txt'}],
               		  },
            'A->1' => [ 'hcluster_run' ],
        },
       -wait_for => [ 'BlastpWithFasta' ],
    },

    # Query blast result from peptide_align_feature table in pipeline database, output file => hcluster.txt
    {  -logic_name 	  => 'hcluster_prepare_input',
        -module       => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
        -parameters   => {
           	'cluster_dir'   => $self->o('output_dir'),
			'pipeline_name' => $self->o('pipeline_name'),
			'cmd'			=> 'mysql '.$self->dbconn_2_mysql('pipeline_db',0).' '.$self->o('pipeline_db','-dbname').' -e "SELECT qmember_id,hmember_id,score FROM peptide_align_feature" | grep  -v qmember_id > #cluster_dir#/hcluster.#ext#',
        },
     },

    # Running hcluster, output file => hcluster.out 
    {   -logic_name	  => 'hcluster_run',
        -module       => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
        -parameters   => {
              'clustering_max_gene_halfcount' => $self->o('clustering_max_gene_halfcount'),
              'cluster_dir'                   => $self->o('output_dir'),
              'hcluster_exe'                  => $self->o('hcluster_exe'),
              'cmd'                           => '#hcluster_exe# -m #clustering_max_gene_halfcount# -w 0 -s 0.34 -O -o #cluster_dir#/hcluster.out #cluster_dir#/hcluster.txt',
           },
        -flow_into => {
            '1->A'	 => ['HclusterParseOutput'],
  	  		'A->1' 	 => ['cluster_factory'],
        },
        -rc_name => '24Gb_job',
    },

    # Parsing hcluster.out file, output file => hcluster_parse.out
    {   -logic_name  => 'HclusterParseOutput',
        -module       => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
        -parameters  => {
            'cluster_dir'               => $self->o('output_dir'),
            'cmd'           => "(echo 'cluster_id\tgenes_count\tcluster_list'; awk '\$6>=2' #cluster_dir#/hcluster.out | cut -f1,6,7 | sed 's/,\$//' ) > #cluster_dir#/hcluster_parse.out",
        },
        -flow_into 		=> {
            '1'  => {'prepare_cluster_factory_input_ids' => [{'ext' => 'txt'}] },
			#'run_qc_tests' => {'groupset_tag' => 'Clusterset' },
        },
    },

# ---------------------------------------------[main tree creation loop]-------------------------------------------------------------

    # Creating file containing list of cluster_ids, output file => cluster_factory_input_ids.txt
    {   -logic_name   => 'prepare_cluster_factory_input_ids',
        -module       => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
        -parameters   => {
            'cluster_dir'   => $self->o('output_dir'),
            'cmd'			=> 'cut -f1 #cluster_dir#/hcluster_parse.out | grep -v cluster_id > #cluster_dir#/cluster_factory_input_ids.#ext#',
         },
        -flow_into 	   => {
            '1'  => {'create_msa_directory'},
        },
    },

    # Create MSA output top directory at the $self->o('output_dir'),
    {   -logic_name   => 'create_msa_directory',
        -module       => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
        -parameters   => {
            'output_dir'   => $self->o('output_dir'),
            'cmd'		   => 'mkdir #output_dir#/msa',
         },
    },

	# Creating jobs for msa_chooser, 1 job for each cluster_id
  	{   -logic_name => 'cluster_factory',
        -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
        -parameters => {
            'inputfile'			=> $self->o('output_dir').'/cluster_factory_input_ids.txt',
            'column_names' 		=> ['cluster_id'],
            'fan_branch_code'   => 2,
        },
        -flow_into  => {
			'2->A' 		 =>	['Mafft'],
			'A->1' 		 =>	['HmmProfileFactory'],
        },
    },
            
    {   -logic_name => 'Mafft',
        -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::Mafft',
        -parameters => {
            #'use_exon_boundaries'       => $self->o('use_exon_boundaries'),
            #'mafft_exe'         => $self->o('mafft_exe'),
            #'mafft_binaries'    => $self->o('mafft_binaries'),
            'mafft_home'        => $self->o('mafft_home'),
            'fasta_file' 	 	=> $self->o('fasta_file'),
            'hcluster_parse'	=> $self->o('output_dir').'/hcluster_parse.out',
            'blast_tmp_dir'     => $self->o('blast_tmp_dir'), # To store fasta file of clusters to perform MSA on
            'msa_dir'			=> $self->o('msa_dir'), 
        },
        -hive_capacity => $self->o('mcoffee_capacity'),
        -rc_name       => 'mcoffee',
        -priority      => 30,
        -batch_size    => 50, 
        -flow_into     => {
              -1 => [ 'Mafft_himem' ],  # MEMLIMIT
        },
    },
        
    {   -logic_name => 'Mafft_himem',
        -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::Mafft',
        -parameters => {
            #'use_exon_boundaries'       => $self->o('use_exon_boundaries'),
            #'mafft_exe'                 => $self->o('mafft_exe'),
            #'mafft_binaries'            => $self->o('mafft_binaries'),
            'mafft_home'        => $self->o('mafft_home'),
            'fasta_file' 	 	=> $self->o('fasta_file'),
            'hcluster_parse'	=> $self->o('output_dir').'/hcluster_parse.out',
            'blast_tmp_dir'     => $self->o('blast_tmp_dir'), # To store fasta file of clusters to perform MSA on
            'msa_dir'			=> $self->o('msa_dir'), 
	   },
        -hive_capacity => $self->o('mcoffee_capacity'),
		-rc_name       => 'mcoffee_himem',
        -priority      => 35,
        -batch_size    => 50, 
    },

# ---------------------------------------------[building hmm profile step]---------------------------------------------------------------------
    
    # Creating jobs for each multiple alignment file
	 {   -logic_name => 'HmmProfileFactory',
         -module     => 'Bio::EnsEMBL::Compara::RunnableDB::BuildHMMprofiles::HmmProfileFactory',
         #-module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HmmProfileFactory',
         -parameters => {
	        'msa_dir'       => $self->o('msa_dir'),               
          },
         -flow_into  => {
                '2->A'	 => ['HmmBuild'],
 		  		'A->1' 	 => ['HmmCalibrateFactory'],
#  		  		'A->1' 	 => ['NotifyUser'],
         },
        -wait_for => [ 'Mafft' ],
     },

    # Run hmmbuild to create HMMer Profile
    {   -logic_name  => 'HmmBuild',
        -module     => 'Bio::EnsEMBL::Compara::RunnableDB::BuildHMMprofiles::HmmBuild',
        #-module      => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HmmBuild',
        -parameters  => {
              'hmmbuild_exe' => $self->o('hmmbuild_exe'),
              'msa_dir'      => $self->o('msa_dir'),
              'hmmLib_dir'   => $self->o('hmmLib_dir'),
              'division'     => $self->o('division'),
           },
        -hive_capacity => $self->o('hmmbuild_capacity'),
        -rc_name       => 'mcoffee_himem',
        -batch_size    => 50,
    },

    # Creating jobs for  calibration  HMMer Profile
	 {   -logic_name => 'HmmCalibrateFactory',
         -module     => 'Bio::EnsEMBL::Compara::RunnableDB::BuildHMMprofiles::HmmCalibrateFactory',
         #-module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HmmCalibrateFactory',
         -parameters => {
	        'hmmLib_dir'  => $self->o('hmmLib_dir'),               
          },
         'fan_branch_code' => 2,
         -flow_into => {
                '2->A'	 => ['HmmCalibrate'],
  		  		'A->1' 	 => ['NotifyUser'],
         },
         -wait_for => [ 'HmmBuild' ],
     },

    # Run hmmcalibrate to calibrate created HMMer Profile
    {   -logic_name  => 'HmmCalibrate',
        -module     => 'Bio::EnsEMBL::Compara::RunnableDB::BuildHMMprofiles::HmmCalibrate',
        #-module      => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HmmCalibrate',
        -parameters  => {
	          'hmmLib_dir'    => $self->o('hmmLib_dir'),     
    	      'hmmcalibrate'  => $self->o('hmmcalibrate'),
           },
        -hive_capacity => $self->o('hmmcalibrate_capacity'),
        -batch_size    => 50,
    },

    ####### NOTIFICATION
    {	-logic_name => 'NotifyUser',
        -module     => 'Bio::EnsEMBL::Hive::RunnableDB::NotifyByEmail',
        -parameters => {
         	'email'       => $self->o('email'),
         	'subject'     => $self->o('pipeline_name').' has finished',
         	'hmmLib_dir'  => $self->o('hmmLib_dir'),
                'text'        => $self->o('pipeline_name')." HMM libraries is available at #hmmLib_dir#.\n"
        },
        -wait_for => [ 'HMMCalibrate' ],
    }
  ];
}

=pod
sub pipeline_wide_parameters {
    my ($self) = @_;

    return {
        %{ $self->SUPER::pipeline_wide_parameters() },  # inherit other stuff from the base class
        release => $self->o('release'),
        species => $self->o('species'),
        division => $self->o('division'),
    };
}

# override the default method, to force an automatic loading of the registry in all workers
sub beekeeper_extra_cmdline_options {
    my $self = shift;    
    return "-reg_conf ".$self->o("registry");
}

=cut

sub resource_classes {
    my $self = shift;
    return {
      'default'  	  => { 'LSF' => '-q production-rh6 -n 4 -M 4000 -R "rusage[mem=4000]"'},
      'mem'     	  => { 'LSF' => '-q production-rh6 -n 4 -M 12000 -R "rusage[mem=12000]"'},
      '2Gb_job'       => {'LSF' => '-q production-rh6 -C0 -M2000  -R"select[mem>2000]  rusage[mem=2000]"' },
      '24Gb_job'      => {'LSF' => '-q production-rh6 -C0 -M24000 -R"select[mem>24000] rusage[mem=24000]"' },
      '500Mb_job'     => {'LSF' => '-q production-rh6 -C0 -M500   -R"select[mem>500]   rusage[mem=500]"' },
	  '1Gb_job'       => {'LSF' => '-q production-rh6 -C0 -M1000  -R"select[mem>1000]  rusage[mem=1000]"' },
	  '2Gb_job'       => {'LSF' => '-q production-rh6 -C0 -M2000  -R"select[mem>2000]  rusage[mem=2000]"' },
	  '8Gb_job'       => {'LSF' => '-q production-rh6 -C0 -M8000  -R"select[mem>8000]  rusage[mem=8000]"' },
	  '24Gb_job'      => {'LSF' => '-q production-rh6 -C0 -M24000 -R"select[mem>24000] rusage[mem=24000]"' },
	  'mcoffee'       => {'LSF' => '-q production-rh6 -W 24:00' },
	  'mcoffee_himem' => {'LSF' => '-q production-rh6 -M 32768 -R "rusage[mem=32768]" -W 24:00' },
    }
}


1;
