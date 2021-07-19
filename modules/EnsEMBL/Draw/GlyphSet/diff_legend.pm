=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Draw::GlyphSet::diff_legend;

use strict;

use base qw(EnsEMBL::Draw::GlyphSet::legend);

sub _init {
  my $self = shift;
  
  my $config    = $self->{'config'};
  return unless $config->{'_difference_legend'};
  
  my @blocks = (
    { 
      legend => 'Insert relative to reference',
      colour => '#2aa52a',
      border => 'black',
    },{
      legend => 'Delete relative to reference',
      colour => 'red',
    },{
      legend => 'Inserts grouped at this scale (zoom to resolve)',
      colour => '#2aa52a', 
      overlay => '..',
      border => 'black',
      test => '_difference_legend_dots',
    },{
      legend => 'Deletes grouped at this scale (zoom to resolve)',
      colour => '#ffdddd',
      test => '_difference_legend_pink',
    },{
      legend => 'Large insert shown truncated due to image scale or edge',
      colour => '#94d294',
      overlay => '...',
      test => '_difference_legend_el',
    },{
      legend => 'Match',
      colour => '#ddddff',
    });

  $self->init_legend(4);
  
  foreach my $b (@blocks) {
    next if $b->{'test'} and not $config->{$b->{'test'}};
    $self->add_to_legend($b);
  }
}

1;
