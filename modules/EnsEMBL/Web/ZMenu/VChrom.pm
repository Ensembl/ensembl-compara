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

package EnsEMBL::Web::ZMenu::VChrom;

use strict;

use base qw(EnsEMBL::Web::ZMenu);

use List::Util qw(min max);

sub _half_way {
  my ($self,$chr,$size) = @_;

  my $sa = $self->hub->get_adaptor('get_SliceAdaptor');
  my $slice = $sa->fetch_by_region(undef,$chr);
  return (1,1) unless($slice);
  return (max(0,$slice->length/2-$size),
          min($slice->length,$slice->length/2+$size));
}

sub content {
  my $self = shift;
  my $hub = $self->hub;

  my $chr = $hub->param('chr');
  my $summary_url = $hub->url({'type' => 'Location',
                                'action' => 'Chromosome',
                                '__clear' => 1, 
                                'r' => $chr});   
  # Half way along, maybe?
  my ($start,$end) = $self->_half_way($chr,50000);
  my $r = sprintf("%s:%d-%d",$chr,$start,$end);
  my $detail_url = $hub->url({ type => 'Location',
                               action => 'View',
                               r => $r });

  $self->caption("Chromosome $chr");
  $self->add_entry({
    type  => 'Summary',
    label => "Chromosome $chr", 
    link => $summary_url,
    order => 1,
  });
  $self->add_entry({
    type => "Example",
    label => "Example region on $chr",
    link => $detail_url,
    order => 2,
  });
}

1;
