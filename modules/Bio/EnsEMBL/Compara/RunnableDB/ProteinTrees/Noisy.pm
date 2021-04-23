=head1 LICENSE

See the NOTICE file distributed with this work for additional information
regarding copyright ownership.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::Noisy;

=head1 DESCRIPTION

This Analysis/RunnableDB is designed to take a root_id as input.
This must already have a multiple alignment run on it. 
It uses that alignment as input to the filterring tool Noisy.

input_id/parameters format eg: "{'gene_tree_id'=>1234}"
    gene_tree_id : use 'id' to fetch a cluster from the ProteinTree

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::Noisy;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::GenericRunnable');

sub param_defaults {
    my $self = shift;
    return { %{ $self->SUPER::param_defaults },
             'cmd'              => '#noisy_exe# -s -v --seqtype #noisy_seqtype# --cutoff #noisy_cutoff# #alignment_file#',
             'noisy_seqtype'    => '#expr(#cdna# ? "D" : "P")expr#',
             'output_file'      => 'align.#gene_tree_id#_out.fas',
             'read_tags'        => 1,
             'runtime_tree_tag' => 'noisy_runtime',
             'do_hcs'           => 0, #if we run HCs in here it will cause erros, since the tree isnt computed at this point.
           };
}

sub get_tags {
    my $self = shift;

    my $removed_columns = $self->parse_filtered_align( $self->param('alignment_file'), $self->param('output_file'), 0, $self->param('gene_tree') );
    print "Trimmed colums: " . $removed_columns . "\n" if $self->debug;
    return { 'removed_columns' => $removed_columns };
}

1;

