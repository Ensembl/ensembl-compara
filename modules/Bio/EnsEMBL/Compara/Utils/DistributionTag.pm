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

Bio::EnsEMBL::Compara::Utils::DistributionTag

=head1 DESCRIPTION

Utility methods for writing distribution tags

=cut

package Bio::EnsEMBL::Compara::Utils::DistributionTag;

use strict;
use warnings;
use base qw(Exporter);

our %EXPORT_TAGS;
our @EXPORT_OK;

@EXPORT_OK = qw(
    write_n_tag
);
%EXPORT_TAGS = (
    all => [@EXPORT_OK]
);

=head2 write_n_tag

    Write the n_label_distribution tags for homology scores

=cut

sub write_n_tag {
    my ($mlss, $label, $scores) = @_;

    my %distrib_hash;
    foreach my $score ( values %$scores ) {
        my $floor_score = int($score/25)*25;
        $distrib_hash{$floor_score} += 1;
    }

    foreach my $distrib_score ( keys %distrib_hash ) {
        my $tag = sprintf('n_%s_%s', $label, $distrib_score // 'null');
        $mlss->store_tag($tag, $distrib_hash{$distrib_score});
    }
}

1;
