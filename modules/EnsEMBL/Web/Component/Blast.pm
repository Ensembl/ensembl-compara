=head1 LICENSE

Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::Blast;

use base qw( EnsEMBL::Web::Component);
use strict;
use warnings;

sub add_alignment_links {
### Compile links to alternative views of alignment data
  my ($self, $current) = @_;
  my $object = $self->object;
  my %lookup = (
    'align' => 'Alignment',
    'query' => 'Query Sequence',
    'genomic' => 'Genomic Sequence',
  );
  my $html;
  foreach my $type (keys %lookup) {
    next if $type eq $current;
    $object->param('display', $type);
    my $url = '/Blast/Alignment?';
    my @new_params;
    foreach my $p ($object->param) {
      push @new_params, $p.'='.$object->param($p);
    }
    $url .= join(';', @new_params);
    $html .= qq(<a href="$url">View ).$lookup{$type}.'</a> ';
  }
  $object->param('display', $current); ## reset CGI parameter
  return $html;
}


1;
