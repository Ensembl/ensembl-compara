
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
         0 => { -desc => 'default',          'LSF' => '-M200000 -R"select[mem>260] rusage[mem=260]"' },
         1 => { -desc => 'hcluster_run',     'LSF' => '-C0 -M1000000 -R"select[mycompara2<500 && mem>1000] rusage[mycompara2=10:duration=10:decay=1:mem=1000]"' },
         2 => { -desc => 'mcoffee_himem',    'LSF' => '-W180 -C0 -M7500000 -R"select[mem>7500] rusage[mem=7500]"' },
         3 => { -desc => 'mcoffee_veryhimem','LSF' => '-W180 -C0 -M15000000 -R"select[mem>15000] rusage[mem=15000]"' },
         4 => { -desc => 'mcoffee',          'LSF' => '-W60 -M2500000 -R"select[mem>2600] rusage[mem=2600]"' },
         5 => { -desc => 'bigish',           'LSF' => '-M1000000 -R"select[mem>1100] rusage[mem=1100]"' },
         9 => { -desc => 'CAFE',             'LSF' => '-M15000000 -R"select[mem>15000] rusage[mem=15000]"'},
    };
}

# each run you will need to specify and uncomment: mlss_id, release, work_dir, dbname
sub default_options {
  my ($self) = @_;
  return {
    %{$self->SUPER::default_options},   # inherit the generic ones

    # parameters that are likely to change from execution to another:
#    'mlss_id'               => 24,   # it is very important to check that this value is current (commented out to make it obligatory to specify)
#    'release'               => '66', # specify and uncomment each run!
    'rel_suffix'            => 'vega',
#    'work_dir'              => '/lustre/scratch101/sanger/ds23/compara/compara-vega47/ds23_vega_genetree_20111219_66_faster', # specify and uncomment each run
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
#      -dbname => 'ds23_vega_genetree_20111219_66_faster', # spcify and uncomment each run
    },

    # the master database for synchronization of various ids
    'master_db' => {
      -host   => 'vegabuild',
      -port   => 5304,
      -user   => 'ottadmin',
      -pass   => $self->o('password'),
      -dbname => 'vega_compara_master',
#      -dbname => 'vega_compara_master_64',
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
    'other_paralogs_capacity'   =>  50,
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

  my $analyses = $self->SUPER::pipeline_analyses;

  my %bigish = map { $_ => 1 } ('hcluster_parse_output','load_fresh_members','njtree_phyml',
                                'store_sequences','store_sequences_factory');
  # fix mcoffee
  foreach $_ (@$analyses) {
    my $name = $_->{'-logic_name'};
    if($name eq 'mcoffee') {
      $_->{'-rc_id'} = 4;
    } elsif($name eq 'dummy_wait_alltrees') {
      push @{$_->{'-wait_for'}},'mcoffee_veryhimem','mcoffee_mafft';
    }
    $_->{'-rc_id'} = 5 if(exists $bigish{$name});
  }
  # find mcoffee_himem and use as template for mcoffee_veryhimem and mcoffee_mafft
  my $himem_i;
  for(my $i=0;$i<@$analyses;$i++) {
    $himem_i = $i if $analyses->[$i]->{'-logic_name'} eq 'mcoffee_himem';
  }
  die "No mcoffee_himem found" unless $himem_i;
  my $himem = $analyses->[$himem_i];
  # fix himem
  $himem->{'-flow_into'}->{-2} = ['mcoffee_veryhimem'];
  $himem->{'-flow_into'}->{-1} = ['mcoffee_veryhimem'];
  # setup veryhimem
  my $veryhimem = dclone($himem);
  $veryhimem->{'-rc_id'} = 3;
  $veryhimem->{'-logic_name'} = 'mcoffee_veryhimem';
  $veryhimem->{'-flow_into'}->{-2} = ['mcoffee_mafft'];
  $veryhimem->{'-flow_into'}->{-1} = ['mcoffee_mafft'];
  # setup mafft
  my $mafft = dclone($himem);
  $mafft->{'-logic_name'} = 'mcoffee_mafft';
  $mafft->{'-parameters'}->{'method'} = 'mafft';
  # add them
  splice(@$analyses,$himem_i+1,0,$veryhimem,$mafft);
  return $analyses;
}

1;

