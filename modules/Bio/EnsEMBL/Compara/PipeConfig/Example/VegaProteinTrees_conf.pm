
=pod 

=head1 NAME

  Bio::EnsEMBL::Compara::PipeConfig::Example::VegaProteinTrees_conf

=head1 SYNOPSIS

    #1. update ensembl-hive, ensembl and ensembl-compara CVS repositories before each new release

    #2. you may need to update 'schema_version' in meta table to the current release number in ensembl-hive/sql/tables.sql

    #3. make sure that all default_options are set correctly

    #4. Run init_pipeline.pl script:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Example::VegaProteinTrees_conf -password <your_password> -mlss_id <your_current_PT_mlss_id>

    #5. Sync and loop the beekeeper.pl as shown in init_pipeline.pl's output


=head1 DESCRIPTION  

    The PipeConfig example file for Vega group's version of ProteinTrees pipeline

=head1 CONTACT

  Please contact Compara or Vega with questions/suggestions

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Example::VegaProteinTrees_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::PipeConfig::ProteinTrees_conf');

use Storable qw(dclone);

sub resource_classes {
  my ($self) = @_;
  return {
    %{$self->SUPER::resource_classes}
  };
}


# each run you will need to specify and uncomment: mlss_id, release, work_dir, dbname
sub default_options {
  my ($self) = @_;
  return {
    %{$self->SUPER::default_options},
    # inherit the generic ones

    # parameters that are likely to change from execution to another:
#    'mlss_id'               => '25',   # it is very important to check that this value is current (commented out to make it obligatory to specify)
#    'release'               => '68',
    'rel_suffix'            => 'vega',
    'work_dir'              => '/lustre/scratch109/ensembl/'.$ENV{'USER'}.'/compara_generation/vega_genetree_20120611_68_3',
    'outgroups'             => [ ],   # affects 'hcluster_dump_input_per_genome'
    'taxlevels'             => [ 'Theria' ],
    'filter_high_coverage'  => 1,   # affects 'group_genomes_under_taxa'

    # connection parameters to various databases:

    # the production database itself (will be created)
    'pipeline_db' => { 
      -host   => 'vegabuild',
      -port   => 5304,
      -user   => 'ottadmin',
      -pass   => $self->o('password'),
      -dbname => $self->o('ENV', 'USER').'_vega_genetree_20120611_'.$self->o('release').'_3',
    },

    # the master database for synchronization of various ids
    'master_db' => {
      -host   => 'vegabuild',
      -port   => 5304,
      -user   => 'ottadmin',
      -pass   => $self->o('password'),
      -dbname => 'vega_compara_master',
    },

    # switch off the reuse:
    'reuse_core_sources_locs'   => [ ],
    'prev_release'              => 0,   # 0 is the default and it means "take current release number and subtract 1"
    'reuse_db'                  => 0,

    # hive_capacity values for some analyses:
    'store_sequences_capacity'  => 50,
    'blastp_capacity'           => 450,
    'mcoffee_capacity'          => 100,
    'njtree_phyml_capacity'     => 70,
    'ortho_tree_capacity'       => 50,
    'build_hmm_capacity'        => 50,
    'other_paralogs_capacity'   => 50,
    'homology_dNdS_capacity'    => 100,

    #if the 65 hive fails at wublast p and you can't work out what's wrong with the path then uncomment this
    'wublastp_exe'              => '/usr/local/ensembl/bin/wublastp',

  };
}

#
# We don't really want to have to maintain our own analysis pipeline, we just want to alter the existing one
# to cope with our issues with exploding mcoffees. So we get the parent analysis and then tinker with it
# rather than specifying it from scratch. This should make it clearer what we're changing and also make it
# more robust to changes in unrelated parts of the analysis.
#
sub pipeline_analyses {
  my ($self) = @_;

  #include non-reference slices
  my $analyses = $self->SUPER::pipeline_analyses;
  foreach (@$analyses) {
    my $name = $_->{'-logic_name'};
    if ($name eq 'load_fresh_members') {
      $_->{'-parameters'}{'include_nonreference'} = 1;
      $_->{'-parameters'}{'include_reference'} = 1;
    }
  }

  return $analyses;

}

1;

