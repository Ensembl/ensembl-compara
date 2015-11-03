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


=pod 

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::Example::VegaProteinTrees_conf

=head1 SYNOPSIS

    #1. update ensembl-hive, ensembl and ensembl-compara GIT repositories before each new release

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
    'urgent_hcluster'   => {'LSF' => '-C0 -M1000 -R"select[mem>1000] rusage[mem=1000]" -q yesterday' },
    '4Gb_job'          => { 'LSF' => '-C0 -M4000  -R"select[mem>4000]  rusage[mem=4000]"' },
  };
}


# each run you will need to edit and uncomment: version, mlss_id and maybe work_dir
sub default_options {
  my ($self) = @_;

  return {
    %{$self->SUPER::default_options},
    # inherit the generic ones

    # parameters that are likely to change from execution to another:
    'mlss_id'               => '100032',   # equivalent to mlss_id for PROTEIN_TREES in the db (commented out to make it obligatory to specify)

    'pipeline_name'         => 'vega_genetree_20150611_80b', #edit this each time

    "registry_dbs" => [{"-host" => "vegp-db","-pass" => "","-port" => 5304,"-user" => "ottro"}],

    'rel_suffix'            => 'vega',
    'work_dir'              => '/lustre/scratch109/ensembl/ds23/compara-80/ds23_vega_genetree_20150611_80b',
    'outgroups'             => { },   # affects 'hcluster_dump_input_per_genome'
    'gene_blacklist_file'   => '/dev/null',
    'taxlevels'             => [ 'Theria' ],
    'filter_high_coverage'  => 1,   # affects 'group_genomes_under_taxa'

    # connection parameters to various databases:
    # the production database itself (will be created)
    'host'   => 'vegp-db',
    'port'   => 5304,
    'user'   => 'ottadmin',

    # the master database for synchronization of various ids
    'master_db' => 'mysql://ottadmin:***PASSWORD***@vegp-db:5304/vega_compara_master',

    # switch off the reuse:
    'reuse_from_prev_rel_db'    => 0,
    'do_stable_id_mapping'      => 0,

    # we're not interested in treefam
    'do_treefam_xref'           => 0,

    # neither in CAFE:
    'initialise_cafe_pipeline'  => 0,

    # hive_capacity values for some analyses:
    'store_sequences_capacity'  => 50,
    'blastp_capacity'           => 450,
    'mcoffee_capacity'          => 100,
    'treebest_capacity'         => 70,
    'ortho_tree_capacity'       => 50,
    'build_hmm_capacity'        => 50,
    'other_paralogs_capacity'   => 50,
    'homology_dNdS_capacity'    => 100,

  };
}

#
# Rather than maintain our own analysis pipeline just want to alter the existing one
# Fortunately, the base config has slots to do that
#

sub analyses_to_remove {
    return [qw(overall_qc email_tree_stats_report)];
}

sub tweak_analyses {
    my $self = shift;
    my $analyses_by_name = shift;

    #include non-reference slices
    $analyses_by_name->{'load_fresh_members_from_db'}->{'-parameters'}{'include_nonreference'} = 1;
    $analyses_by_name->{'load_fresh_members_from_db'}->{'-parameters'}{'include_reference'} = 1;
    $analyses_by_name->{'load_fresh_members_from_db'}->{'-parameters'}{'store_missing_dnafrags'} = 1;
    $analyses_by_name->{'load_fresh_members_from_db'}->{'-parameters'}{'force_unique_canonical'} = 1;
}

1;

