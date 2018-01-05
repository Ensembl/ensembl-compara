
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
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::GetPatterns;

use strict;
use warnings;
use Time::HiRes qw(time gettimeofday tv_interval);

use base ('Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::GenericRunnable');

sub param_defaults {
    my $self = shift;
    return {
        %{ $self->SUPER::param_defaults },
        'cmd' => '#getPatterns_exe# -s #alignment_file# -m PROTGAMMAJTT -n #gene_tree_id#',
        'aln_format'       => 'phylip',
        'runtime_tree_tag' => 'parser_examl_runtime',
        'output_file'      => 'RAxML_info.#gene_tree_id#',
        'minimum_genes'    => 4,
        'read_tags'        => 1,
        'remove_columns'   => 1,
        'do_hcs'           => 0, #if we run HCs in here it will cause erros, since the tree isnt computed at this point.
	};
}

sub get_tags {
    my $self = shift;

    my $num_of_patterns;
    my $num_redundant = 0;
    open( my $output_file, "<", $self->param('output_file') );
    while (<$output_file>) {
        if (/Found (\d+) sequences that are exactly identical to other sequences in the alignment/) {
            $num_redundant = $1;
        }
        if ( $_ =~ /^Alignment has/ ) {
			my @tok = split (/\s/,$_);
			$num_of_patterns = $tok[2];
        }
    }

    my $num_sequences = scalar(@{ $self->param('gene_tree')->get_all_leaves });

    print "num_of_patterns: $num_of_patterns\n" if $self->debug;
    print "num_redundant_sequences: $num_redundant\n" if $self->debug;
    return { 'aln_num_of_patterns' => $num_of_patterns, 'num_distinct_sequences' => $num_sequences-$num_redundant };
}

1;
