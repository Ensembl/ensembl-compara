=head1 LICENSE

  Copyright (c) 1999-2013 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

   http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

  Bio::EnsEMBL::Compara::PipeConfig::Example::EGProteinTrees_conf

=head1 SYNOPSIS

    #1. update ensembl-hive, ensembl and ensembl-compara CVS repositories before each new release

    #2. you may need to update 'schema_version' in meta table to the current release number in ensembl-hive/sql/tables.sql

    #3. make sure that all default_options are set correctly

    #4. Run init_pipeline.pl script:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Example::EGProteinTrees_conf \
        -password <your_password> -mlss_id <your_current_PT_mlss_id> \
        -division <eg_division> -eg_release <egrelease> -release <release>

    #5. Sync and loop the beekeeper.pl as shown in init_pipeline.pl's output


=head1 DESCRIPTION

    The PipeConfig example file for Ensembl Genomes group's version of
    ProteinTrees pipeline. This file is inherited from & customised further
    within the Ensembl Genomes infrastructure but this file serves as
    an example of the type of configuration we perform.

=head1 CONTACT

  Please contact Compara or Ensembl Genomes with questions/suggestions

=cut


package Bio::EnsEMBL::Compara::PipeConfig::Example::EGProteinTrees_conf;

use strict;
use warnings;
use Bio::EnsEMBL::Utils::Exception qw(throw);

use base qw(Bio::EnsEMBL::Compara::PipeConfig::ProteinTrees_conf);

sub _pipeline_db_options {
  my ($self) = @_;
  return {
    prefix => 'ensembl_compara',
    suffix => 'hom_'.$self->o('eg_release').'_'.$self->o('release'),
    rel_suffix => '', #done to override the idea of suffix which we do not have
    db_name => $self->o('prefix').q{_}.$self->o('division').q{_}.$self->o('suffix'),
  };
}

sub default_options {
  my ($self) = @_;

  #Parent defaults
  my $parent = $self->SUPER::default_options();

  #Local defaults
  my %options = (

    #Globals
#    mlss_id => 40043,
#    division_name => 'pyrococcus_collection',
    %{$self->_pipeline_db_options()},

    pipeline_name => 'PT_'.$self->o('mlss_id'),

    #Dirs
#    ensembl_cvs_root_dir  =>  '',
    exe_dir               =>  '/nfs/panda/ensemblgenomes/production/compara/binaries',
    base_dir              =>  '/nfs/nobackup2/ensemblgenomes/'.$self->o('ENV', 'USER').'/compara',
    work_dir              =>  $self->o('base_dir').'/'.$self->o('db_name'),
  #  blast_tmp_dir         =>  '/tmp/'.$self->o('mlss_id').'/blastTmp',

    #Executables
    hcluster_exe    =>  $self->o('exe_dir').'/hcluster_sg',
    mcoffee_exe     =>  $self->o('exe_dir').'/t_coffee',
    mcoffee_home    => '/nfs/panda/ensemblgenomes/external/t-coffee', 	
    mafft_home      =>  '/nfs/panda/ensemblgenomes/external/mafft',
    sreformat_exe   =>  $self->o('exe_dir').'/sreformat',
    treebest_exe    =>  $self->o('exe_dir').'/treebest',
    quicktree_exe   =>  $self->o('exe_dir').'/quicktree',
    buildhmm_exe    =>  $self->o('exe_dir').'/hmmbuild',
    codeml_exe      =>  $self->o('exe_dir').'/codeml',
    ktreedist_exe   =>  $self->o('exe_dir').'/ktreedist',
   'blast_bin_dir'  => '/nfs/panda/ensemblgenomes/external/ncbi-blast-2+/bin/',

    # HMM specific parameters
   'hmm_clustering'            => 0, ## by default run blastp clustering
   'cm_file_or_directory'      => '/nfs/production/panda/ensemblgenomes/data/PANTHER7.2/',
   'hmm_library_basedir'       => '/nfs/production/panda/ensemblgenomes/data/PANTHER7.2/',
   'pantherScore_path'         => '/nfs/panda/ensemblgenomes/data/pantherScore1.03/',
   'hmmer_path'                => '/nfs/panda/ensemblgenomes/external/hmmer-2.3.2-x86_64-Linux/src/',


    #Clustering
    outgroups => [],

    #Trees
    use_genomedb_id         =>  0,
#    tree_dir                =>  $self->o('ensembl_cvs_root_dir').'/../ensembl_genomes/EGCompara/config/prod/trees/Version'.$self->o('eg_release').'Trees',
#    species_tree_input_file =>  $self->o('tree_dir').'/'.$self->o('division').'.peptide.nh',

    # hive_capacity values for some analyses:
    'reuse_capacity'            =>   4,
    'blast_factory_capacity'    =>  50,
    'blastp_capacity'           => 200,
    'mcoffee_capacity'          => 200,
    'split_genes_capacity'      => 200,
    'njtree_phyml_capacity'     => 200,
    'ortho_tree_capacity'       => 200,
    'ortho_tree_annot_capacity' => 300,
    'quick_tree_break_capacity' => 100,
    'build_hmm_capacity'        => 200,
    'ktreedist_capacity'        => 150,
    'merge_supertrees_capacity' => 100,
    'other_paralogs_capacity'   => 100,
    'homology_dNdS_capacity'    => 200,
    'qc_capacity'               =>   4,
    'hc_capacity'               =>   4,
    'HMMer_classify_capacity'   => 100,

    # hive priority for non-LOCAL health_check analysis:
    'hc_priority'               => 10,

    #DNDS
    codeml_parameters_file  => $self->o('ensembl_cvs_root_dir').'/ensembl-compara/scripts/homology/codeml.ctl.hash',
    taxlevels               => ['cellular organisms'],
    filter_high_coverage    => 0,

    ###### DB WORK
    pipeline_db => {
      -host   => $self->o('host'),
      -port   => $self->o('port'),
      -user   => $self->o('username'),
      -pass   => $self->o('password'),
      -dbname => $self->o('db_name'),
    },

    master_db => {
      -host   => 'mysql-eg-pan-1.ebi.ac.uk',
      -port   => 4276,
      -user   => 'ensro',
      -pass   => '',
      -dbname => 'ensembl_compara_master',
    },

    ######## THESE ARE PASSED INTO LOAD_REGISTRY_FROM_DB SO PASS IN DB_VERSION
    ######## ALSO RAISE THE POINT ABOUT LOAD_FROM_MULTIPLE_DBs

    prod_1 => {
      -host   => 'mysql-eg-prod-1.ebi.ac.uk',
      -port   => 4238,
      -user   => 'ensro',
      -db_version => $self->o('release')
    },

    staging_1 => {
      -host   => 'mysql-eg-staging-1.ebi.ac.uk',
      -port   => 4160,
      -user   => 'ensro',
      -db_version => $self->o('release')
    },

    staging_2 => {
      -host   => 'mysql-eg-staging-2.ebi.ac.uk',
      -port   => 4275,
      -user   => 'ensro',
      -db_version => $self->o('release')
    },

    # Add the database location of the previous Compara release
    prev_rel_db => {
       -host   => 'mysql-eg-staging-1.ebi.ac.uk',
       -port   => 4160,
       -user   => 'ensro',       
       -dbname => 'ensembl_compara_metazoa_19_72'
    },

    prev_release              => 0,   # 0 is the default and it means "take current release number and subtract 1"

    # Are we reusing the dbIDs and the blastp alignments ?
    'reuse_from_prev_rel_db'    => 0,
    'force_blast_run'           => 1,

    curr_core_sources_locs => [ $self->o('prod_1') ],
    reuse_from_prev_rel_db => 0,  #Set this to 1 to enable the reuse
    # Add the database entries for the core databases of the previous release
    'prev_core_sources_locs'   => [ $self->o('staging_1') ],
      
    # do_not_reuse_list => ['guillardia_theta'], # set this to empty or to the genome db names we should ignore

  );

  #Combine & return
  return {%{$parent}, %options};
}

sub pipeline_wide_parameters {
  my ($self) = @_;
  return {
    %{$self->SUPER::pipeline_wide_parameters()},
    'email'         => $self->o('email')
  };
}

sub pipeline_create_commands {
  my ($self) = @_;
  return [
    @{$self->SUPER::pipeline_create_commands()},
  ];
}

sub resource_classes {
  my ($self) = @_;
  return {
         'default'      => {'LSF' => '-q production-rh6' },
         '250Mb_job'    => {'LSF' => '-q production-rh6 -M250   -R"select[mem>250]   rusage[mem=250]"' },
         '500Mb_job'    => {'LSF' => '-q production-rh6 -M500   -R"select[mem>500]   rusage[mem=500]"' },
         '1Gb_job'      => {'LSF' => '-q production-rh6 -M1000  -R"select[mem>1000]  rusage[mem=1000]"' },
         '2Gb_job'      => {'LSF' => '-q production-rh6 -M2000  -R"select[mem>2000]  rusage[mem=2000]"' },
         '8Gb_job'      => {'LSF' => '-q production-rh6 -M8000  -R"select[mem>8000]  rusage[mem=8000]"' },
         '500Mb_long_job'    => {'LSF' => '-q production-rh6 -M500   -R"select[mem>500]   rusage[mem=500]"' },
         'urgent_hcluster'     => {'LSF' => '-q production-rh6 -M32000 -R"select[mem>32000] rusage[mem=32000]"' },
         'msa'      => {'LSF' => '-q production-rh6 -W 24:00' },
         'msa_himem'    => {'LSF' => '-q production-rh6 -M 32768 -R"select[mem>32768] rusage[mem=32768]" -W 24:00' },
  };
}

sub pipeline_analyses {
  my ($self) = @_;
  my $analyses = $self->SUPER::pipeline_analyses();
  my $new_analyses = $self->_new_analyses();
  push(@{$analyses}, @{$new_analyses});
  $self->_modify_analyses($analyses);
  return $analyses;
}

sub _new_analyses {
  my ($self) = @_;
  return [
    {
      -logic_name => 'divison_tag_protein_trees',
      -module => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      -parameters => { },
      -flow_into => {
        1 => { 'mysql:////gene_tree_root_tag' => { root_id => '#gene_tree_id#', tag => 'division', value => $self->o('division') } }
      }
    },
  ];
}

sub _modify_analyses {
  my ($self, $list) = @_;

  foreach my $analysis (@{$list}) {
    if ($analysis->{'-logic_name'} eq 'ortho_tree') {
      #Get normal flow to send a job to division_tag_protein_trees all the time
      #rather than having the flow do the write; for some reason this old
      #version stopped working
	push(@{$analysis->{-flow_into}}, 'divison_tag_protein_trees'); 
    }
  }

}

1;
