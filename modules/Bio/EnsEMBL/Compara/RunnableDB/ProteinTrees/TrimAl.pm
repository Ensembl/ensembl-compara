
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

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::TrimAl;

=head1 DESCRIPTION

This Analysis/RunnableDB is designed to take a root_id as input.
This must already have a multiple alignment run on it. That
alignment is filered by TrimAl. and stored in the "removed_columns"
tree tag.

input_id/parameters format eg: "{'gene_tree_id'=>1234}"
    gene_tree_id : use 'id' to fetch a cluster from the ProteinTree

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the CVS log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::TrimAl;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::GenericRunnable');

sub param_defaults {
    my $self = shift;
    return {
        %{$self->SUPER::param_defaults},

        'cmd'               => '#trimal_exe# -in  #alignment_file# -automated1 > #gene_tree_id#.filtered',
        'output_file'       => '#gene_tree_id#.filtered',
        'read_tags'         => 1,
        'runtime_tree_tag'  => 'trimal_runtime',
    };
}



## We redefine get_tags to populate the removed_columns tag the right way

sub get_tags {
    my $self = shift;

    while (1) {
        my $removed_columns = $self->parse_filtered_align( $self->param('alignment_file'), $self->param('output_file'), 0, $self->param('gene_tree') );
        print "Trimmed colums: ".$removed_columns."\n" if $self->debug;
        return { 'removed_columns' => $removed_columns } unless $self->param('removed_members');
        $self->warning("There are removed members, so we need to re-run TrimAl.\n");
        delete $self->param('gene_tree')->{'_member_array'};
        $self->run;
    }
}

1;

