
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
    %{$self->SUPER::resource_classes}
  };
}


# each run you will need to specify and uncomment: mlss_id, release, work_dir, dbname
sub default_options {
  my ($self) = @_;
  my $version = 'vega_genetree_20120822_69_2'; #edit this each time
  return {
    %{$self->SUPER::default_options},
    # inherit the generic ones

    # parameters that are likely to change from execution to another:
#    'mlss_id'               => '25',   # equivalent to mlss_id for PROTEIN_TREES in the db (commented out to make it obligatory to specify)
    'release'               => '69',

    'rel_suffix'            => 'vega',
    'work_dir'              => '/lustre/scratch109/ensembl/'.$ENV{'USER'}.'/compara_generation/'.$version,
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
      -dbname => $self->o('ENV', 'USER').'_'.$version,
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

    #if the hive fails at wublast p and you can't work out what's wrong with the path then uncomment this
#    'wublastp_exe'              => '/usr/local/ensembl/bin/wublastp',

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

  my $new_analyses = $self->_new_analyses();
  push(@{$analyses}, @{$new_analyses});
  return $analyses;

}

#add any new analyses
sub _new_analyses {
  my ($self) = @_;

  #update_display_member labels (borrowed from EG)
  return [
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
      -wait_for => ['backbone_fire_dnds'],
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
  ];
}

1;

