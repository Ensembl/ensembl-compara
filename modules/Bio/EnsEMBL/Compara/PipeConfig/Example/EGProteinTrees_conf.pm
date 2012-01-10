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
    #eg_release=9
    #release=61

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
    base_dir              =>  '/nfs/panda/ensemblgenomes/production/compara/'.$self->o('ENV', 'USER').'/hive',
    work_dir              =>  $self->o('base_dir').'/'.$self->o('mlss_id').'/PT',
    blast_tmp_dir         =>  $self->o('work_dir').'/blastTmp',

    #Executables
    wublastp_exe    =>  'wublastp',
    hcluster_exe    =>  $self->o('exe_dir').'/hcluster_sg',
    mcoffee_exe     =>  $self->o('exe_dir').'/t_coffee',
    mafft_exe       =>  $self->o('exe_dir').'/mafft-distro/bin/mafft',
    mafft_binaries  =>  $self->o('exe_dir').'/mafft-distro/lib/mafft',
    sreformat_exe   =>  $self->o('exe_dir').'/sreformat',
    treebest_exe    =>  $self->o('exe_dir').'/treebest',
    quicktree_exe   =>  $self->o('exe_dir').'/quicktree',
    buildhmm_exe    =>  $self->o('exe_dir').'/hmmbuild',
    codeml_exe      =>  $self->o('exe_dir').'/codeml',

    #Clustering
    outgroups => [],

    #Trees
    use_exon_boundaries     =>  0,
    use_genomedb_id         =>  1,
    tree_dir                =>  $self->o('ensembl_cvs_root_dir').'/EGCompara/config/prod/trees/Version'.$self->o('eg_release').'Trees',
#    species_tree_input_file =>  $self->o('tree_dir').'/'.$self->o('division_name').'.peptide.nh',

    #DNDS
    codeml_parameters_file  => $self->o('ensembl_cvs_root_dir').'/EGCompara/config/prod/configs/Release'.$self->o('eg_release').'/codeml.ctl.hash',
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

#    master_db => {
#      -host   => '',
#      -port   => 1,
#      -user   => '',
#      -pass   => '',
#      -dbname => 'ensembl_compara_master',
#    },

    ######## THESE ARE PASSED INTO LOAD_REGISTRY_FROM_DB SO PASS IN DB_VERSION
    ######## ALSO RAISE THE POINT ABOUT LOAD_FROM_MULTIPLE_DBs

#    clusterprod_1 => {
#      -host   => '',
#      -port   => 1,
#      -user   => '',
#      -db_version => $self->o('release')
#    },
#
#    staging_1 => {
#      -host   => '',
#      -port   => 1,
#      -user   => '',
#      -db_version => $self->o('release')
#    },
#
#    staging_2 => {
#      -host   => '',
#      -port   => ,
#      -user   => 'ensro',
#      -db_version => $self->o('release')
#    },

    prev_release              => 0,   # 0 is the default and it means "take current release number and subtract 1"

    reuse_core_sources_locs   => [],
    reuse_db                  => q{}, #Set to this to ignore reuse otherwise ....

    do_not_reuse_list => [], # set this to empty or to the genome db names we should ignore

#    reuse_core_sources_locs   => [ $self->o('staging_2') ],
#    curr_core_sources_locs    => [ $self->o('clusterprod_1') ],
#    reuse_db                  => {
#       -host   => '',
#       -port   => 1,
#       -user   => 'ensro',
#       -pass   => '',
#       -dbname => '',
#    },

    #Set these up to perform stable ID mapping

#    stable_id_prev_rel_db => {
#      #HOST PARAMS
#    },

    #To skip set prev_rel_db to empty; other params do need to be set though
    stable_id_prev_release_db => q{},
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
    0 => { -desc => 'default',          'LSF' => '-q production' },
    1 => { -desc => 'hcluster_run',     'LSF' => '-q production -M 16384 -R "rusage[mem=16384]"' },
    2 => { -desc => 'mcoffee_himem',    'LSF' => '-q production -M 32768 -R "rusage[mem=32768]" -W 24:00' },
    3 => { -desc => 'mcoffee',          'LSF' => '-q production -W 24:00' },
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
        1 => { 'mysql:////gene_tree_root_tag' => { node_id => '#protein_tree_id#', tag => 'division', value => $self->o('division_name') } }
      }
    },
    {
      -logic_name => 'member_display_labels_factory',
      -module => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
      -parameters => {
        inputquery      => 'select genome_db_id from species_set ss join method_link_species_set mlss using (species_set_id) where mlss.method_link_species_set_id = '.$self->o('mlss_id'),
        column_names    => [qw/genome_db_id/],
        input_id        => { genome_db_ids => ['#genome_db_id#'] },
        fan_branch_code => 1,
      },
      -input_ids => [
        {}
      ],
      -wait_for => ['overall_genetreeset_qc'],
      -flow_into => {
        1 => [ 'update_member_display_labels' ]
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
      -wait_for => ['overall_genetreeset_qc']
    }
  ];
}

sub _modify_analyses {
  my ($self, $list) = @_;

  #Mcoffee resource alteration
  $self->_get_analysis($list, 'mcoffee')->{-rc_id} = 3;

  #Get normal flow to send a job to division_tag_protein_trees all the time
  #rather than having the flow do the write; for some reason this old
  #version stopped working
  push(@{$self->_get_analysis($list, 'ortho_tree')->{-flow_into}->{1}}, 'divison_tag_protein_trees');

  return;
}

sub _get_analysis {
  my ($self, $list, $name) = @_;
  foreach my $analysis (@{$list}) {
    return $analysis if $analysis->{'-logic_name'} eq $name;
  }
  throw('Cannot find an analysis for '.$name)
}

1;
