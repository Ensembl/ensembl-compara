=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Object::DataExport;

use strict;
use warnings;

use base qw(EnsEMBL::Web::Object);

sub caption       { return 'Export';  }
sub short_caption { return 'Export';  }


sub expand_slice {
  my ($self, $slice) = @_;
  my $hub = $self->hub;
  $slice ||= $hub->core_object('location')->slice;
  my $lrg = $hub->param('lrg');
  my $lrg_slice;

  if ($slice) {
     my ($flank5, $flank3) = map $self->param($_), qw(flank5_display flank3_display);
     $slice = $slice->invert if ($hub->param('strand') eq '-1');
     return $flank5 || $flank3 ? $slice->expand($flank5, $flank3) : $slice;
   }

  if ($lrg) {
    eval { $lrg_slice = $hub->get_adaptor('get_SliceAdaptor')->fetch_by_region('LRG', $lrg); };
  }
  return $lrg_slice;
}



1;
