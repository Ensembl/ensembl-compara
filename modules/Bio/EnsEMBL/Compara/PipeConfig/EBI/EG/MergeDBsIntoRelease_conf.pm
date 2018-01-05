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

Bio::EnsEMBL::Compara::PipeConfig::EGMergeDBsIntoRelease_conf

=head1 SYNOPSIS

    #1. update all databases' names and locations

    #2. initialize the pipeline:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::EBI::EG::MergeDBsIntoRelease_conf -password <your_password>

    #3. run the beekeeper.pl

=head1 DESCRIPTION

A pipeline to merge some production databases onto the release one.
It is currently working well only with the "gene side" of Compara
(protein_trees, families and ncrna_trees)
because synteny_region_id is not ranged by MLSS.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::EBI::EG::MergeDBsIntoRelease_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::PipeConfig::MergeDBsIntoRelease_conf');


sub default_options {
  my ($self) = @_;
  return {
  %{$self->SUPER::default_options},

  # Where the pipeline database will be created
  'host' => undef,

  # Also used to differentiate submitted processes
  'pipeline_name' => 'pipeline_dbmerge_'.$self->o('rel_with_suffix'),

  # Don't shout about unknown tables
  'die_if_unknown_table'    => 0,

  'reg_conf' => undef,

  # All the source databases
  'src_db_aliases' => {},

  # The target database
  'curr_rel_db' => undef,

  # From these databases, only copy these tables
  'only_tables' => {
    # Cannot be copied by populate_new_database because it doesn't contain the new mapping_session_ids yet
    'master_db' => [qw(mapping_session)],
  },

  # These tables have a unique source. Content from other databases is ignored
  'exclusive_tables'  => {
    'mapping_session'         => 'master_db',
    'peptide_align_feature_%' => 'protein_db',
  },

  # In these databases, ignore these tables
  'ignored_tables' => {
    'protein_db' => [qw(all_cov_ortho poor_cov_ortho poor_cov_2 dubious_seqs)],
    'family_db'  => [qw(gene_member seq_member sequence)],
  },

  };
}

sub resource_classes {
  my ($self) = @_;
  return {
    %{$self->SUPER::resource_classes},
    'default' => { 'LSF' => '-q production-rh7' },
  };
}

1;
