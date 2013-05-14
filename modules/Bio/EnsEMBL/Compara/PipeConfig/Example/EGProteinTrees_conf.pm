=pod

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
    eg_release=>19,
    release=>72,
    division_name=>'protists',

    prefix => 'ensembl_compara',
    suffix => 'hom_'.$self->o('eg_release').'_'.$self->o('release'), #output hom_9_61
    rel_suffix => '', #done to override the idea of suffix which we do not have
    db_name => $self->o('prefix').q{_}.$self->o('division_name').q{_}.$self->o('suffix'),
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
    base_dir              =>  '/nfs/nobackup/ensemblgenomes/uma/workspace/compara/'.$self->o('ENV', 'USER').'/hive',
    work_dir              =>  $self->o('base_dir').'/'.$self->o('mlss_id').'/PT',
  #  blast_tmp_dir         =>  '/tmp/'.$self->o('mlss_id').'/blastTmp',

    #Executables
    wublastp_exe    =>  $self->o('exe_dir').'/wublast/blastp',
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

    # HMM specific parameters
   'hmm_clustering'            => 0, ## by default run blastp clustering
   'cm_file_or_directory'      => '/nfs/production/panda/ensemblgenomes/data/PANTHER7.2/',
   'hmm_library_basedir'       => '/nfs/production/panda/ensemblgenomes/data/PANTHER7.2/',
   'blast_path'                => '/nfs/panda/ensemblgenomes/external/ncbi-blast-2.2.23+-x86_64-Linux/bin/',
   'pantherScore_path'         => '/nfs/panda/ensemblgenomes/data/pantherScore1.03/',
   'hmmer_path'                => '/nfs/panda/ensemblgenomes/external/hmmer-2.3.2-x86_64-Linux/src/',


    #Clustering
    outgroups => [],

    #Trees
    use_genomedb_id         =>  0,
   # tree_dir                =>  $self->o('ensembl_cvs_root_dir').'/EGCompara/config/prod/trees/Version'.$self->o('eg_release').'Trees',
#    species_tree_input_file =>  $self->o('tree_dir').'/'.$self->o('division_name').'.peptide.nh',

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
        'merge_supertrees_capacity' => 100,
        'other_paralogs_capacity'   => 100,
        'homology_dNdS_capacity'    => 200,
        'qc_capacity'               =>   4,
        'hc_capacity'               =>   4,
        'HMMer_classify_capacity'   => 100,

    #DNDS
    codeml_parameters_file  => $self->o('ensembl_cvs_root_dir').'ensembl-compara/scripts/homology/codeml.ctl.hash',
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

   staging_2 => {
      -host   => 'mysql-eg-staging-2.ebi.ac.uk',
      -port   => 4275,
      -user   => 'ensro',
      -db_version => $self->o('release')
    },

    staging_1 => {
      -host   => 'mysql-eg-staging-1.ebi.ac.uk',
      -port   => 4160,
      -user   => 'ensro',
      -db_version => $self->o('release')
    },

   	clusterprod_1 => {
      -host   => 'mysql-cluster-eg-prod-1.ebi.ac.uk',
      -port   => 4238,
      -user   => 'ensro',
      -db_version => $self->o('release')
    },

    prev_release              => 0,   # 0 is the default and it means "take current release number and subtract 1"

    #reuse_core_sources_locs   => [],
    reuse_db                  => q{}, #Set to this to ignore reuse otherwise ....

    #do_not_reuse_list => ['guillardia_theta'], # set this to empty or to the genome db names we should ignore

    reuse_core_sources_locs   => [ $self->o('staging_2') ],
    curr_core_sources_locs    => [ $self->o('clusterprod_1') ],
   # reuse_db                  => {
    #   -host   => 'mysql-eg-staging-2.ebi.ac.uk',
    #   -port   => 4272,
    #   -user   => 'ensro',
    #   -pass   => '',
    #   -dbname => 'ensembl_compara_protists_18_71',
   # },

    #Set these up to perform stable ID mapping

    stable_id_prev_release_db => {
       -host   => 'mysql-eg-staging-2.ebi.ac.uk',
       -port   => 4275,
       -user   => 'ensro',
       -pass   => '',
       -dbname => 'ensembl_compara_protists_18_71',

    },

    #To skip set prev_rel_db to empty; other params do need to be set though
    stable_id_release => $self->o('eg_release'),
    stable_id_prev_release => q{}, #means default to last -1

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
    'mkdir -p '.$self->o('blast_tmp_dir'),
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
         'msa_himem'    => {'LSF' => '-q production-rh6 -M 32768 -R "rusage[mem=32768]" -W 24:00' },
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
        1 => { 'mysql:////gene_tree_root_tag' => { root_id => '#gene_tree_id#', tag => 'division', value => $self->o('division_name') } }
      }
    },
    {
      -logic_name => 'member_display_labels_factory',
      -module => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
      -parameters => {
        inputquery      => 'select genome_db_id from species_set ss join method_link_species_set mlss using (species_set_id) where mlss.method_link_species_set_id = '.$self->o('mlss_id'),
      },
      -input_ids => [
        {}
      ],
      -wait_for => ['backbone_fire_dnds'],
      -flow_into => {
        2 => { 'update_member_display_labels' => { genome_db_ids => ['#genome_db_id#'] } }
      }
    },
    {
      -logic_name => 'update_member_display_labels',
      -module => 'Bio::EnsEMBL::Compara::RunnableDB::MemberDisplayLabelUpdater',
      -parameters => {
        die_if_no_core_adaptor => 1
      },
      -hive_capacity => 10,
      -batch_size => 1
    },
    {
      -logic_name => 'stable_id_mapping',
      -module => 'Bio::EnsEMBL::Compara::RunnableDB::StableIdMapper',
      -parameters => {
        master_db => $self->o('master_db'),
        prev_rel_db => $self->o('stable_id_prev_release_db'),
        release => $self->o('stable_id_release'),
        type => 't',
        prev_release => $self->o('stable_id_prev_release')
      },
      -input_ids => [
        {}
      ],
      -wait_for => ['backbone_fire_dnds']
    }
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
