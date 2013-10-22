
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
use base ('Bio::EnsEMBL::Compara::PipeConfig::Example::EnsemblProteinTrees_conf');

use Storable qw(dclone);

sub resource_classes {
  my ($self) = @_;
  return {
    %{$self->SUPER::resource_classes},
    'urgent_hcluster'   => {'LSF' => '-C0 -M1000000 -R"select[mem>1000] rusage[mem=1000]" -q yesterday' },
  };
}


# each run you will need to specify and uncomment: mlss_id, release, work_dir, dbname
sub default_options {
  my ($self) = @_;
  return {
    %{$self->SUPER::default_options},
    # inherit the generic ones

    # parameters that are likely to change from execution to another:
    'mlss_id'               => '25',   # equivalent to mlss_id for PROTEIN_TREES in the db (commented out to make it obligatory to specify)
    'release'               => '71',

    'pipeline_name'         => 'vega_genetree_20130211_71_step3', #edit this each time

    'rel_suffix'            => 'vega',
    'work_dir'              => '/lustre/scratch109/sanger/'.$ENV{'USER'}.'/compara_generation/'.$self->o('pipeline_name'),
    'outgroups'             => { },   # affects 'hcluster_dump_input_per_genome'
    'taxlevels'             => [ 'Theria' ],
    'filter_high_coverage'  => 1,   # affects 'group_genomes_under_taxa'

    # connection parameters to various databases:

    # the production database itself (will be created)
    'host'   => 'vegabuild',
    'port'   => 5304,
    'user'   => 'ottadmin',

    # the master database for synchronization of various ids
    'master_db' => 'mysql://ottro@vegabuild:5304/vega_compara_master',

    # switch off the reuse:
    'prev_core_sources_locs'   => [ ],
    'do_stable_id_mapping'      => 0,

    # hive_capacity values for some analyses:
    'store_sequences_capacity'  => 50,
    'blastp_capacity'           => 450,
    'mcoffee_capacity'          => 100,
    'njtree_phyml_capacity'     => 70,
    'ortho_tree_capacity'       => 50,
    'build_hmm_capacity'        => 50,
    'other_paralogs_capacity'   => 50,
    'homology_dNdS_capacity'    => 100,

  };
}

#
# We don't really want to have to maintain our own analysis pipeline, if needed we just want to alter the existing one
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

