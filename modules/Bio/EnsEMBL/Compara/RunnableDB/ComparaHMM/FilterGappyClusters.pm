
=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2020] EMBL-European Bioinformatics Institute

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

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::FilterGappyClusters

=head1 SYNOPSIS

This runnable is used to:
    1 - get percentage of gaps
    2 - use max_gappiness parameter to remove unwanted profiles 

=head1 DESCRIPTION

This Analysis/RunnableDB is designed to filter out clusters that are too gappy.
It uses the max_gappiness parameter as a cutoff.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::FilterGappyClusters;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::AlignmentFilteringTagging');

sub run {
    my $self = shift @_;

    my $gappiness = $self->_get_gappiness();
    $self->param( 'gappiness', $gappiness );
}

sub write_output {
    my $self = shift @_;

    $self->param('gene_tree')->store_tag('gappiness',$self->param('gappiness'));

    if ( $self->param('gappiness') < $self->param('max_gappiness') ) {

        #delete cluster from clusterset_id default and copy to filter_level_1
        print "Moving " . $self->param('gene_tree_id') . " to filter_level_2 clusterset\n" if ( $self->debug );
        $self->param('gene_tree_adaptor')->change_clusterset( $self->param('gene_tree'), "filter_level_2" );
    };
}

1;
