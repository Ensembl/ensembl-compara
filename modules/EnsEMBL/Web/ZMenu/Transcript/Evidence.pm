=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::ZMenu::Transcript::Evidence;

use strict;
use warnings;

## Although this class is inherited from EnsEMBL::Web::ZMenu::Transcript, it can not display Exon link using the inherited functionalities since it does not have click region coords,
## but instead it has exon id which is used to display exon row

use parent qw(EnsEMBL::Web::ZMenu::Transcript);

sub content {
  my $self  = shift;
  my $hub   = $self->hub;
  my $exon  = $hub->param('exon');

  $self->SUPER::content;

  if ($exon) {
    $self->add_entry({
      'type'      => 'Exon',
      'label'     => $exon,
      'link'      => $hub->url({ type => 'Transcript', action => 'Exons', exon => $_ }),
      'position'  => 1
    });
  }
}

1;
