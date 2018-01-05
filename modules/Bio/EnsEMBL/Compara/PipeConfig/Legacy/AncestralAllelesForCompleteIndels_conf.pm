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

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::Legacy::AncestralAllelesForCompleteIndels_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Legacy::AncestralAllelesForCompleteIndels_conf -password <your_password> -mlss_id <alignment method_link_species_set_id>

=head1 DESCRIPTION  

This pipeline determines the consequences of 1 bp indels at each position in the reference species in an alignment. 

An alignment region is spliced out which covers "flank" characters to the left and right of the current base. This is realigned to form the "reference alignment". 
eg Using homo sapiens as the reference species and a flank region of 10 around the asterixed "C":
           *
 TTTGATTGCACTGTGGTCTGA homo_sapiens
 TTTGATTGCACTGTGGTCTGA pan_troglodytes
 TTTGATTGCACTGTGGTCTGA gorilla_gorilla
 TTTGATTGCACTGTGGTCTGA pongo_abelii
 TTTGATTGCAC-ATGGTCTGA macaca_mulatta

A set of "alternative alignments" are calculated by creating a new sequence for the reference species by either inserting a base to the left of the current base or deleting the current base. To reduce the number of computations, we only insert bases that are non-identical to the current base, for example, if the current base is "C", we will insert the bases "A", "G" and "T" and realign. 
eg Inserting an "A":
                  *
 TTTGATTGC | AA | CTGTGGTCTGA homo_sapiens
 TTTGATTGC | -A | CTGTGGTCTGA pan_troglodytes
 TTTGATTGC | -A | CTGTGGTCTGA gorilla_gorilla
 TTTGATTGC | -A | CTGTGGTCTGA pongo_abelii
 TTTGATTGC | -A | C-ATGGTCTGA macaca_mulatta
 TTTGATTGC | AA | CTGTGGTCTGA -ALTERNATIVE ALLELE-
 TTTGATTGC | -A | CTGTGGTCTGA -ANCESTRAL ALLELE-

eg Deleting the "C":
 TTTGATTGCA | - | TGTGGTCTGA homo_sapiens
 TTTGATTGCA | C | TGTGGTCTGA pan_troglodytes
 TTTGATTGCA | C | TGTGGTCTGA gorilla_gorilla
 TTTGATTGCA | C | TGTGGTCTGA pongo_abelii
 TTTGATTGCA | C | -ATGGTCTGA macaca_mulatta
 TTTGATTGCA | - | TGTGGTCTGA -ALTERNATIVE ALLELE-
 TTTGATTGCA | C | TGTGGTCTGA -ANCESTRAL ALLELE-

The consequences of the insertion or deletion are determined by studying the reference, alternative and ancestral alleles. This is summarised in the output file.
eg
11      76932627        C       s;A     i       4       A       AA      A;G     i       4       -       G       -;T     i       4       -       T       -;C     d       1       C       -       C;

The first 2 columns are seq_region and base position.
The next 2 columns are the substitution ancestral allele and "s" followed by a ";" delimiter
The next 4 ";" delimited fields are the insertion (i) or deletion (d) consequences:
   inserted_or_deleted_base i|d event_flag reference_allele alternative_allele ancestral_allele

The event flags are defined in Bio::EnsEMBL::Compara::RunnableDB::AncestralAllelesForIndels::AncestralAllelesCompleteBase

A more verbose output can be obtained by setting the verbose_vep flag. More output in a separate file is available by setting the verbose flag (recommended for small regions only)

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=cut


package Bio::EnsEMBL::Compara::PipeConfig::Legacy::AncestralAllelesForCompleteIndels_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');

sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},
            'db_version' => 73, #ensembl version (to load core dbs)

            'pipeline_name' => 'ancestral_' . $self->o('db_version'),
            'ref_species' => 'homo_sapiens',
            'chunk_size' => 10000, #sub-chunk size
            'vep_size' => 1000000, #size of final vep files for indexing
            'flank' => 10,
            'max_allele_length' => 1, #only support 1bp indels

            #maximum total alignment length (including gaps). Alignments of greater length will
            #be discarded because a large insertion causes difficulties for ortheus
            'max_alignment_length' => 100, 

            'seq_region' => '',
            'coord_system_name' => 'chromosome',
            'mlss_id' => undef,  #method_link_species_set_id for the alignment. Define on the command line.

            #verbose output written to separate file "indel_"
            'verbose' => 0,

            #verbose output in the output file used for input to 'VEP'
            'verbose_vep' => 0,

            #location of ftp dump of ancestor files 
            'ancestor_dir' => "/lustre/scratch109/ensembl/kb3/scratch/ancestral_alleles/homo_sapiens_ancestor_GRCh37_e71/",

            'summary_file' => 'summary.txt',

            #executables
            'bgzip_exe' => '/software/CGP/bin/bgzip',
            'tabix_exe' => '/software/CGP/bin/tabix',

            #specify these urls specifically instead of loading all by url so I can use the disconnect_when_inactive settings for
            #the core dbs set in the genome_db table
            'compara_url' => 'mysql://ensro@ens-livemirror:3306/ensembl_compara_' . $self->o('db_version'),

            # ancestral seqs db connection parameters
            'ancestor_host' => 'ens-livemirror',
            'ancestor_user' => 'ensro',
            'ancestor_port' => 3306,
            'ancestor_species_name' => 'ancestral_sequences',
            'ancestor_dbname' => 'ensembl_ancestral_' . $self->o('db_version'),

            # master database connection parameters
            'master_db'  => 'mysql://ensro@compara1/mm14_ensembl_compara_master',

            'pipeline_db' => {                                  # connection parameters
                              -host   => 'compara5',
                              -port   => 3306,
                              -user   => 'ensadmin',
                              -pass   => $self->o('password'),
                              -dbname => $ENV{USER}.'_'.$self->o('pipeline_name'),
                              -driver => 'mysql',
                             },

            #Location of core databases
            'reg1' => {
                       -host   => 'ens-livemirror',
                       -port   => 3306,
                       -user   => 'ensro',
                       -pass   => '',
                       -driver => 'mysql',
                       -dbname => '73',
                      },
            'curr_core_sources_locs'    => [ $self->o('reg1') ],
           };

    
}

sub pipeline_create_commands {
    my ($self) = @_;
    return [
        @{$self->SUPER::pipeline_create_commands},  # inheriting database and hive tables' creation
        
        #Store DumpMultiAlign healthcheck results
        $self->db_cmd('CREATE TABLE IF NOT EXISTS statistics (
        statistics_id               INT(10) unsigned NOT NULL AUTO_INCREMENT,
        seq_region                  varchar(40) DEFAULT "" NOT NULL,
        seq_region_start            INT(10) DEFAULT 1,
        seq_region_end              INT(10) DEFAULT 0,
        total_bases		    INT(10) DEFAULT 0,
        all_N 	                    INT(10) DEFAULT 0,
        low_complexity	            INT(10) DEFAULT 0,
        multiple_gats	            INT(10) DEFAULT 0,
        no_gat	                    INT(10) DEFAULT 0,
        insufficient_gat            INT(10) DEFAULT 0,
        long_alignment              INT(10) DEFAULT 0,
        align_all_N                 INT(10) DEFAULT 0,
        num_bases_analysed          INT(10) DEFAULT 0,
        PRIMARY KEY (statistics_id),
        UNIQUE KEY seq_region_start_end  (seq_region, seq_region_start, seq_region_end)
        ) COLLATE=latin1_swedish_ci ENGINE=InnoDB;'),

        $self->db_cmd('CREATE TABLE IF NOT EXISTS event (
         statistics_id              INT(10) unsigned NOT NULL,
#         microinversion             tinyint(2) unsigned NOT NULL DEFAULT 0,
         indel                      ENUM("insertion", "deletion"),
         type                       ENUM("novel", "recovery", "unsure"),
         detail                     ENUM("of_allele_base", "strict", "shuffle", "realign", "neighbouring_deletion", "neighbouring_insertion", "complex"),
         detail1                    ENUM("strict1", "shuffle1"),
         improvement                ENUM("better", "worse"),
         detail2                    ENUM("polymorphic_insertion","polymorphic_deletion","complex_polymorphic_insertion", "complex_polymorphic_deletion", "funny_polymorphic_insertion", "funny_polymorphic_deletion"),
         count                      INT(10) DEFAULT 0,
         FOREIGN KEY (statistics_id) REFERENCES statistics(statistics_id)
        ) COLLATE=latin1_swedish_ci ENGINE=InnoDB;'),

    ];
}

sub resource_classes {
    my ($self) = @_;
    return {
         %{$self->SUPER::resource_classes},  # inherit 'default' from the parent class

	 '100Mb' => { 'LSF' => '-C0 -M100 -R"select[mem>100] rusage[mem=100]"' },
	 '1Gb'   => { 'LSF' => '-C0 -M1000 -R"select[mem>1000] rusage[mem=1000]"' },
         '5.0Gb' => { 'LSF' => '-C0 -M5000 -R"select[mem>5000] rusage[mem=5000]"' },
    };
}

sub pipeline_analyses {
    my ($self) = @_;
    return [

	    {-logic_name    => 'copy_table',
	     -module        => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
	     -parameters    => {
				'mode'          => 'overwrite',
				'filter_cmd'    => 'sed "s/ENGINE=MyISAM/ENGINE=InnoDB/"',
                                'src_db_conn'   => $self->o('master_db'),
                                'table'         => 'ncbi_taxa_node',
			       },
             -input_ids     => [ {} ],
	     -hive_capacity => 10,
	     -flow_into => {
			    '1->A' => ['load_genomedb_factory' , 'load_ancestral_genomedb'],
                            'A->1' => ['chunked_jobs_factory'], #backbone
			   },
	     -rc_name => '100Mb',
	    },
	    {   -logic_name => 'load_genomedb_factory',
                -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
		-parameters => {
				'compara_db'    => $self->o('master_db'),   # that's where genome_db_ids come from
				'mlss_id'       => $self->o('mlss_id'),
                                'extra_parameters'      => [ 'locator' ],
			       },
		-flow_into => {
                               2 => { 'load_genomedb' => { 'master_dbID' => '#genome_db_id#', 'locator' => '#locator#' }, },
			      },
		-rc_name => '100Mb',
	    },

	    {   -logic_name => 'load_genomedb',
		-module     => 'Bio::EnsEMBL::Compara::RunnableDB::LoadOneGenomeDB',
		-parameters => {
				'registry_dbs'  => $self->o('curr_core_sources_locs'),
                                'db_version'    => $self->o('db_version'),
			       },
		-hive_capacity => 1,    # they are all short jobs, no point doing them in parallel
		-rc_name => '100Mb',
	    },


            {   -logic_name => 'load_ancestral_genomedb',
		-module     => 'Bio::EnsEMBL::Compara::RunnableDB::LoadAncestralGenomeDB',
		-parameters => {
                                'master_db' => $self->o('master_db'),
                                'anc_user' => $self->o('ancestor_user'),
                                'anc_host' => $self->o('ancestor_host'),
                                'anc_port' => $self->o('ancestor_port'),
                                'anc_dbname' => $self->o('ancestor_dbname'),
                                'anc_name' => $self->o('ancestor_species_name'),
			       },
		-hive_capacity => 1,    # they are all short jobs, no point doing them in parallel
		-rc_name => '100Mb',
	    },

            #Find all dnafrags for ref_species
            {   -logic_name => 'chunked_jobs_factory',
                -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
                -parameters => {
                                'db_conn'    => $self->o('compara_url'),
                                'ref_species' => $self->o('ref_species'),
                                'coord_system_name' => $self->o('coord_system_name'),
                                'inputquery' => "SELECT DISTINCT(dnafrag.name) AS seq_region FROM dnafrag LEFT JOIN genome_db USING (genome_db_id) WHERE genome_db.name = \"#ref_species#\" AND coord_system_name= \"#coord_system_name#\" AND is_reference = 1 ORDER BY seq_region",

                                #Development testing only. Create jobs for chr 22 only
#                                'inputquery' => "SELECT DISTINCT(dnafrag.name) AS seq_region FROM dnafrag LEFT JOIN genome_db USING (genome_db_id) WHERE genome_db.name = \"#ref_species#\" AND coord_system_name= \"#coord_system_name#\" AND is_reference = 1 AND dnafrag.name = \"22\" ORDER BY seq_region",
                               },
                -flow_into => {
                               '2' => [ 'create_chunked_jobs' ],
                              },
            },

	    { -logic_name => 'create_chunked_jobs',
	      -module => 'Bio::EnsEMBL::Compara::RunnableDB::AncestralAllelesForIndels::CreateCompleteChunkedJobs',
	      -parameters => {
			      'url'         =>  $self->dbconn_2_url('reg1'),
			      'compara_url' => $self->o('compara_url'),
			      'ref_species' => $self->o('ref_species'),
			      'chunk_size'  => $self->o('vep_size'),
                              'seq_region'  => $self->o('seq_region'),
                              'work_dir'    => $self->o('work_dir'),
                              'mlss_id'     => $self->o('mlss_id'),
			     },
	      -flow_into => {
                             '2->A' => [ 'create_sub_chunk_jobs' ],
                             'A->1' => [ 'summary' ],
			      },

	      -rc_name => '100Mb',
	    },
            { -logic_name => 'create_sub_chunk_jobs',
              -module => 'Bio::EnsEMBL::Compara::RunnableDB::AncestralAllelesForIndels::CreateSubChunkedJobs',
              -parameters => {
			      'chunk_size' => $self->o('vep_size'),
			      'sub_chunk_size' => $self->o('chunk_size'),
                              'seq_region' => $self->o('seq_region'),
			     },
              -flow_into => {
                               '2->A' => [ 'ancestral_alleles_for_indels' ],
                               'A->1' => [ 'concat_vep' ],
                            },
              -rc_name => '100Mb',
            },
	    { -logic_name => 'ancestral_alleles_for_indels',
	      -module => 'Bio::EnsEMBL::Compara::RunnableDB::AncestralAllelesForIndels::RunAncestralAllelesCompleteFork',
#	      -module => 'Bio::EnsEMBL::Compara::RunnableDB::AncestralAllelesForIndels::RunAncestralAllelesComplete',
	      -parameters => {
			      'compara_url' => $self->o('compara_url'),
			      'ref_species' => $self->o('ref_species'),
			      'flank' => $self->o('flank'),
			      'work_dir' => $self->o('work_dir'),
			      'max_allele_length' => $self->o('max_allele_length'),
			      'max_alignment_length' => $self->o('max_alignment_length'),
                              'ancestor_dir' => $self->o('ancestor_dir'),
                              'verbose' => $self->o('verbose'),
			     },
              -batch_size => 1, #this *must* be 1 if using RunAncestralAllelesCompleteFork module
	      -hive_capacity => 500,
	      -rc_name => '1Gb',
              -flow_into => {
                             -1 => [ 'ancestral_alleles_for_indels_himem' ],  # MEMLIMIT
                            },
	    },
            { -logic_name => 'ancestral_alleles_for_indels_himem',
              -module => 'Bio::EnsEMBL::Compara::RunnableDB::AncestralAllelesForIndels::RunAncestralAllelesCompleteFork',
#              -module => 'Bio::EnsEMBL::Compara::RunnableDB::AncestralAllelesForIndels::RunAncestralAllelesComplete',
	      -parameters => {
			      'compara_url' => $self->o('compara_url'),
			      'ref_species' => $self->o('ref_species'),
			      'flank' => $self->o('flank'),
			      'work_dir' => $self->o('work_dir'),
			      'max_allele_length' => $self->o('max_allele_length'),
			      'max_alignment_length' => $self->o('max_alignment_length'),
                              'ancestor_dir' => $self->o('ancestor_dir'),
                              'verbose' => $self->o('verbose'),
			     },
              -batch_size => 1, #this *must* be 1 if using RunAncestralAllelesCompleteFork module
	      -hive_capacity => 500,
              -can_be_empty  => 1,
	      -rc_name => '5.0Gb',
	    },
            { -logic_name => 'concat_vep',
	      -module => 'Bio::EnsEMBL::Compara::RunnableDB::AncestralAllelesForIndels::ConcatVep',
	      -parameters => {
			      'work_dir' => $self->o('work_dir'),
                              'bgzip' => $self->o('bgzip_exe'),
                              'tabix' => $self->o('tabix_exe'),
			     },
	      -rc_name => '100Mb',
              -hive_capacity => 10,
	    },
	    { -logic_name => 'summary',
	      -module => 'Bio::EnsEMBL::Compara::RunnableDB::AncestralAllelesForIndels::CompleteSummary',
	      -parameters => {
			      'summary_file' => $self->o('summary_file'),
                              'work_dir' => $self->o('work_dir'),
                              'seq_region' => $self->o('seq_region'),
			     },
	      -rc_name => '100Mb',
	    },

    ];
}

1;

