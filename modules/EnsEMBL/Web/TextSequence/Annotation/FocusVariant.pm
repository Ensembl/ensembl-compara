=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::TextSequence::Annotation::FocusVariant;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::TextSequence::Annotation);

sub annotate {
  my ($self, $config, $sl, $mk, $seq) = @_;

  foreach (@{$config->{'focus_position'} || []}) {
    $mk->{'variants'}{$_}{'align'} = 1;
    # XXX naughty messing with other's markup
    delete $mk->{'variants'}{$_}{'href'} if $sl->{'main_slice'}; # delete link on the focus variation on the primary species, since we're already looking at it
  }
}

1;
