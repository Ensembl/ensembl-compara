=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::PipeConfig::EPO_pt1_conf

=head1 SYNOPSIS

    #1. Update ensembl-hive, ensembl and ensembl-compara GIT repositories before each new release

    #3. Check all default_options, you will probably need to change the following :
        pipeline_db (-host)
        resource_classes 

        'password' - your mysql password
	'compara_pairwise_db' - I'm assuiming that all of your pairwise alignments are in one compara db
	'reference_genome_db_id' - the genome_db_id (ie the species) which is in all your pairwise alignments
	'list_of_pairwise_mlss_ids' - a comma separated string containing all the pairwise method_link_species_set_id(s) you wise to use to generate the anchors
	'main_core_dbs' - the servers(s) hosting most/all of the core (species) dbs
	'core_db_urls' - any additional core dbs (not in 'main_core_dbs')
        The dummy values - you should not need to change these unless they clash with pre-existing values associated with the pairwise alignments you are going to use

    #4. Run init_pipeline.pl script:
        Using command line arguments:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::EPO_pt1_conf.pm

    #5. Run the "beekeeper.pl ... -sync" and then " -loop" command suggested by init_pipeline.pl

    #6. Fix the code when it crashes

=head1 DESCRIPTION  

    This configuaration file gives defaults for the first part of the EPO pipeline (this part generates the anchors from pairwise alignments). 

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::EPO_pt1_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');
use Data::Dumper;

sub default_options {
    my ($self) = @_;

    return {
	%{$self->SUPER::default_options},
        'pipeline_name' => 'compara_GenerateAnchors',
	'species_tree_file' => $self->o('ensembl_cvs_root_dir').'/ensembl-compara/scripts/pipeline/species_tree_blength.nh',
	   # parameters that are likely to change from execution to another:
	'core_db_version' => 74, # version of the dbs from which to get the pairwise alignments
	   # connection parameters to various databases:
	'pipeline_db' => { # the production database itself (will be created)
		-host   => 'compara4',
                -driver => 'mysql',
		-port   => 3306,
                -user   => 'ensadmin',
		-pass   => $self->o('password'),
		-dbname => $ENV{'USER'}.'_6fish_gen_anchors_'.$self->o('rel_with_suffix'),
   	},
	  # database containing the pairwise alignments needed to get the overlaps
	'compara_pairwise_db' => {
		-user => 'ensro',
		-port => 3306,
		-host => 'ens-livemirror',
		-driver => 'mysql',
		-pass => '',
		-dbname => 'ensembl_compara_72',
	},
	# location of most of the core dbs - to get the sequence from
        'main_core_dbs' => [
          {
            -user => 'ensro',
            -port => 3306,
            -host => 'ens-livemirror',
	    -driver => 'mysql',
            -dbname => '',
            -db_version => $self->o('core_db_version'),
          },
        ],
        # any additional core dbs
        'additional_core_db_urls' => { 
#                'gallus_gallus' => 'mysql://ensro@ens-staging1:3306/gallus_gallus_core_73_4',
        },  

	  # genome_db_id from which pairwise alignments will be used
	'reference_genome_db_id' => 142,
	'list_of_pairwise_mlss_ids' => "634,635,636",
	  # location of species core dbs which were used in the pairwise alignments
	'core_db_urls' => [ 'mysql://ensro@ens-livemirror:3306/72' ],
	  # alignment chunk size
	'chunk_size' => 100000000,
	  # max block size for pecan to align
	'pecan_block_size' => 1000000,
	'pecan_mlid' => 10, # dummy value (change if necessary)
	'pecan_mlssid' => 10, # dummy value
	'gerp_ce_mlid' => 11, # dummy value 
	'gerp_ce_mlssid' => 20, # dummy value
	'gerp_program_version' => "2.1",
	'gerp_exe_dir' => "/software/ensembl/compara/gerp/GERPv2.1",
	'species_set_id' => 10000, # dummy value for reference and non-reference species
	'overlaps_mlid' => 10000, # dummy value 
	'overlaps_method_link_name' => 'GEN_ANCS',
	'overlaps_mlssid' => 10000, # dummy value
	'max_frag_diff' => 1.5, # max difference in sizes between non-reference dnafrag and reference to generate the overlaps from
	'min_ce_length' => 40, # min length of each sequence in the constrained elenent 
        'min_anchor_size' => 50, # at least one of the sequences in an anchor must be of this size
	'max_anchor_seq_len' => 100, # anchors longer than this value will be trimmed
	'min_number_of_seqs_per_anchor' => 2, # minimum number of sequences in an anchor
	'max_number_of_seqs_per_anchor' => 30, # maximum number of sequences in an anchor - can happen due to duplicates or repeats
        'exonerate' => '/software/ensembl/compara/exonerate/exonerate', # path to exonerate executable
     };
}


sub resource_classes {
    my ($self) = @_; 
    return {
	%{$self->SUPER::resource_classes},  # inherit 'default' from the parent class
         'default' => {'LSF' => '-C0 -M2500 -R"select[mem>2500] rusage[mem=2500]"' },	# farm3 lsf syntax$
         'mem3500' => {'LSF' => '-C0 -M3500 -R"select[mem>3500] rusage[mem=3500]"' },	# farm3 lsf syntax$
         'mem7500' => {'LSF' => '-C0 -M7500 -R"select[mem>7500] rusage[mem=7500]"' },  	# farm3 lsf syntax$
         'mem14000' => {'LSF' => '-C0 -M14000 -R"select[mem>14000] rusage[mem=14000]"' },  	# farm3 lsf syntax$
    };  
}

sub pipeline_wide_parameters {
	my $self = shift @_;
	return {
		%{$self->SUPER::pipeline_wide_parameters},

		'compara_pairwise_db' => $self->o('compara_pairwise_db'),
		'list_of_pairwise_mlss_ids' => $self->o('list_of_pairwise_mlss_ids'), 		
		'main_core_dbs' => $self->o('main_core_dbs'),
                'additional_core_db_urls' => $self->o('additional_core_db_urls'),
        	'pecan_mlid' => $self->o('pecan_mlid'),
	        'pecan_mlssid' => $self->o('pecan_mlssid'),
	        'gerp_ce_mlid' => $self->o('gerp_ce_mlid'),
		'gerp_ce_mlssid' => $self->o('gerp_ce_mlssid'),
        	'overlaps_mlid' => $self->o('overlaps_mlid'),
        	'overlaps_method_link_name' => $self->o('overlaps_method_link_name'),
		'overlaps_mlssid' => $self->o('overlaps_mlssid'),
		'min_anchor_size' => $self->o('min_anchor_size'),
		'min_number_of_seqs_per_anchor' => $self->o('min_number_of_seqs_per_anchor'),
		'max_number_of_seqs_per_anchor' => $self->o('max_number_of_seqs_per_anchor'),
		'max_frag_diff' => $self->o('max_frag_diff'),
	        'reference_genome_db_id' => $self->o('reference_genome_db_id'),
		'exonerate' => $self->o('exonerate'),
	};
	
}

sub pipeline_analyses {
	my ($self) = @_;
	print "pipeline_analyses\n";

return [
# ------------------------------------- set up the necessary database tables
    @{$self->init_basic_tables_analyses('#compara_pairwise_db#', 'delete_from_copied_tables', 1, 0, 1, [{}])},

    # FIXME: assembly_default does not exist any more
{
  -logic_name => 'delete_from_copied_tables',
  -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
  -parameters => {
   'sql' => [
    'DELETE FROM method_link_species_set WHERE method_link_species_set_id NOT IN (#list_of_pairwise_mlss_ids#)',
    'DELETE sh.* FROM species_set_header sh LEFT OUTER JOIN method_link_species_set mlss ON sh.species_set_id = mlss.species_set_id WHERE mlss.species_set_id IS NULL',
    'DELETE ss.* FROM species_set ss LEFT OUTER JOIN method_link_species_set mlss ON ss.species_set_id = mlss.species_set_id WHERE mlss.species_set_id IS NULL',
    'DELETE df.*, gdb.* FROM dnafrag df INNER JOIN genome_db gdb ON gdb.genome_db_id = df.genome_db_id LEFT OUTER JOIN species_set ss ON gdb.genome_db_id = ss.genome_db_id WHERE ss.genome_db_id IS NULL',
   'DELETE FROM genome_db WHERE ! assembly_default',
   ],
  },
 -flow_into => { 1 => [ 'add_dummy_mlss_info' ] },
},

{ # this sets values in the method_link_species_set and species_set tables
  -logic_name     => 'add_dummy_mlss_info',
  -module         => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
  -parameters => {
      'species_set_id'  => $self->o('species_set_id'),
      'sql' => [
      # method_link (ml) and method_link_species_set (mlss) entries for the overlaps, pecan and gerp
      'REPLACE INTO method_link (method_link_id, type) VALUES(#overlaps_mlid#, "#overlaps_method_link_name#")',
      'REPLACE INTO method_link_species_set (method_link_species_set_id, method_link_id, name, species_set_id) VALUES '
      .'(#overlaps_mlssid#, #overlaps_mlid#, "get_overlaps", #species_set_id#),'
      .'(#pecan_mlssid#, #pecan_mlid#, "pecan", #species_set_id#),'
      .'(#gerp_ce_mlssid#, #gerp_ce_mlid#, "gerp", #species_set_id#),',
      ],
 },
 -flow_into => { 
   '1->A' => [ 'add_dummy_species_set_info_factory', 'set_genome_db_locator_factory' ],
   'A->1' => [ 'chunk_reference_dnafrags_factory' ],
 },
},

{ # this sets dummy values into the species_set table
    # FIXME : direct writes into species_set are forbidden !
 -logic_name     => 'add_dummy_species_set_info_factory',
 -module         => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
 -parameters => {
  'inputquery' => 'SELECT genome_db_id FROM genome_db',
  'species_set_id' => $self->o('species_set_id'), 
 },
 -flow_into => { 2 => { 'mysql:////species_set' => { 'species_set_id' => '#species_set_id#', 'genome_db_id' => '#genome_db_id#' } } }, 
},

{
 -logic_name => 'set_genome_db_locator_factory',
 -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
 -parameters => {
   'inputquery' => 'SELECT name AS species_loc_name FROM genome_db WHERE assembly_default',
  },
 -flow_into => { 2 => 'update_genome_db_locator', 1 => 'make_species_tree', },
},

{ # this sets up the locator field in the genome_db table
 -logic_name => 'update_genome_db_locator',
 -module     => 'Bio::EnsEMBL::Compara::Production::EPOanchors::UpdateGenomeDBLocator',
 -meadow_type    => 'LOCAL',
},

{
 -logic_name    => 'make_species_tree',
 -module        => 'Bio::EnsEMBL::Compara::RunnableDB::MakeSpeciesTree',
 -parameters    => {
   'mlss_id' => '#pecan_mlssid#',
   'newick_format' => 'simple',
   'blength_tree_file' => $self->o('species_tree_file'),    
 },
 # -flow_into => {
 #   4 => { 'mysql:////method_link_species_set_tag' => { 'method_link_species_set_id' => '#mlss_id#', 'tag' => 'species_tree', 'value' => '#species_tree_string#' } },
 # },
},

# ------------------------------------- now for the modules which create the anchors

{ # split the reference genome in to convenient sized frags for parallelisation
 -logic_name	=> 'chunk_reference_dnafrags_factory',
 -module		=> 'Bio::EnsEMBL::Compara::Production::EPOanchors::ChunkRefDnaFragsFactory',
 -parameters	=> {
   'chunk_size' => $self->o('chunk_size'),
 },
 -flow_into	=> {
	'2->A' => [ 'find_pairwise_overlaps' ],
	'A->1' => [ 'transfer_ce_data_to_anchor_align' ],
  },
},

{ # finds the overlaps between the pairwise lignments and populates the dnafrag_region and synteny_region tables with the overlaps  
 -logic_name	=> 'find_pairwise_overlaps',
 -module		=> 'Bio::EnsEMBL::Compara::Production::EPOanchors::FindPairwiseOverlaps',
 -flow_into	=> {
		2 => [ 'pecan' ],
		3 => [ 'mysql:////dnafrag_region?insertion_method=INSERT_IGNORE' ],
	},
 -failed_job_tolerance => 5, # allowing 5% of job failures
 -hive_capacity => 50,
 -batch_size    => 20,
},

{ # align the overlapping regions - creates entries in the genomic_align and genomic_align_block tables
 -logic_name    => 'pecan',
 -module        => 'Bio::EnsEMBL::Compara::RunnableDB::MercatorPecan::Pecan',
 -parameters    => { 
  'mlss_id' => '#pecan_mlssid#',
  'max_block_size' => $self->o('pecan_block_size'),
  'java_options' => '-server -Xmx1000M',
   },
 -flow_into      => {
		2 => [ 'pecan_high_mem' ],  # Pecan complained
		-1 => [ 'pecan_high_mem' ],  # LSF killed because of MEMLIMIT
		1 => [ 'gerp_constrained_element' ],
   },
 -hive_capacity => 50,
 -failed_job_tolerance => 10, # a proportion of these will probably fail - which is fine 
 -max_retry_count => 1,
},

{    
 -logic_name => 'pecan_high_mem',
 -parameters => {
   'mlss_id' => '#pecan_mlssid#',
   'max_block_size' => $self->o('pecan_block_size'),
   java_options => '-server -Xmx6000M',
 },  
 -module => 'Bio::EnsEMBL::Compara::RunnableDB::MercatorPecan::Pecan',
 -hive_capacity => 10, 
 -rc_name => 'mem7500',
 -failed_job_tolerance => 10,
 -max_retry_count => 1,
 -flow_into      => {
		1 => [ 'gerp_constrained_element' ],
   },
},  

{ # find the most highly constrained regions from the aligned overlaps - this will create entries in the constrained element table
 -logic_name    => 'gerp_constrained_element',
 -module => 'Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::Gerp',
 -parameters    => { 'window_sizes' => '[1,10,100,500]', 'gerp_exe_dir' => $self->o('gerp_exe_dir'), 
	'program_version' => $self->o('gerp_program_version'), 'mlss_id' => '#pecan_mlssid#', },
 -hive_capacity => 100,
 -batch_size    => 10,
 -failed_job_tolerance => 10,
},

{ # copies the constrained element data to the anchor_align table 
 -logic_name     => 'transfer_ce_data_to_anchor_align',
 -module         => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
 -parameters => {
   'sql' => [
		'INSERT INTO anchor_align (method_link_species_set_id, anchor_id, dnafrag_id, dnafrag_start, dnafrag_end, dnafrag_strand) '.
		'SELECT method_link_species_set_id, constrained_element_id, dnafrag_id, dnafrag_start, dnafrag_end, dnafrag_strand FROM '. 
		'constrained_element WHERE (dnafrag_end - dnafrag_start + 1) >= '. $self->o('min_ce_length') .' ORDER BY constrained_element_id',
	],
  },
 -flow_into      => { 1 => 'trim_anchor_align_factory' },
},

{ 
 -logic_name => 'trim_anchor_align_factory',
 -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
 -parameters => {
    'inputquery'      => "SELECT DISTINCT(anchor_id) AS anchor_id FROM anchor_align",
 },  
 -flow_into => {
    '2->A' => [ 'trim_anchor_align' ],
    'A->1' => [ 'load_anchor_sequence_factory' ],
 },  
},  

{ # finds the best cut position within an anchor and trims the anchor positions down to 2 base pairs - it populates the anchor_align table with these trimmed anchors
 -logic_name => 'trim_anchor_align',			
 -module     => 'Bio::EnsEMBL::Compara::Production::EPOanchors::TrimAnchorAlign',
 -parameters => {
    'input_method_link_species_set_id' => '#gerp_ce_mlssid#',
    'output_method_link_species_set_id' => '#overlaps_mlssid#',
  },
 -failed_job_tolerance => 10,
 -hive_capacity => 200,
 -batch_size    => 10,
 -flow_into     => {
     -1 => [ 'trim_anchor_align_himem' ],
 }
},

{ # finds the best cut position within an anchor and trims the anchor positions down to 2 base pairs - it populates the anchor_align table with these trimmed anchors
 -logic_name => 'trim_anchor_align_himem',
 -module     => 'Bio::EnsEMBL::Compara::Production::EPOanchors::TrimAnchorAlign',
 -parameters => {
    'input_method_link_species_set_id' => '#gerp_ce_mlssid#',
    'output_method_link_species_set_id' => '#overlaps_mlssid#',
  },
 -rc_name => 'mem7500',
 -failed_job_tolerance => 10,
 -hive_capacity => 200,
 -batch_size    => 10,
},

{ 
 -logic_name => 'load_anchor_sequence_factory',
 -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
 -parameters => {
	'inputquery'  => 'SELECT DISTINCT(anchor_id) AS anchor_id FROM anchor_align WHERE method_link_species_set_id = #overlaps_mlssid',
  },
 -flow_into => {
	2 => [ 'load_anchor_sequence' ],	
  }, 
},	

{ # using the anchor positions from 'trim_anchor_align' it populates the anchor_sequence table with anchor sequences between min_ce_length and max_anchor_seq_len (using the 2bp trim coord as a mid-point 
 -logic_name => 'load_anchor_sequence',
 -module     => 'Bio::EnsEMBL::Compara::Production::EPOanchors::LoadAnchorSequence',
 -parameters => {
    'input_method_link_species_set_id' => '#overlaps_mlssid#',
    'max_anchor_seq_len' => $self->o('max_anchor_seq_len'),
    'min_anchor_seq_len' => $self->o('min_ce_length'),
 },
 -batch_size    => 10,
 -hive_capacity => 100,
},
];
}	


1;
