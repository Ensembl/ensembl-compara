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

package EnsEMBL::Draw::Output::Blocks;

### Simple module to render one or more features as solid blocks

use strict;

use parent qw(EnsEMBL::Draw::Output);

sub render {
  my ($self, $options) = @_;

  my $colour  = $self->track_config->get('colour');
  my $height  = $options->{'height'} || $self->track_config('height') || $self->default_height;
  my $width   = $self->{'container'}->length;
  my $depth   = 1;
  
  my @features = @{$self->{'data'}||[]}; 

  ## Start position
  my $position = {
                    x       => $features[0]->{'start'} > 1 ? $features[0]->{'start'} - 1 : 0,
                    y       => 0,
                    width   => 0,
                    height  => $height,
                  };

  my $composite;

  if (scalar @features == 1 and !$depth) { #and $config->{'simpleblock_optimise'}) {
    $composite = $self;
  } 
  else {
    $composite = $self->create_Composite({
                                          %$position,
                                          href  => '',
                                          class => 'group',
                                        });

    $position = $composite;
  }
  foreach my $f (@features) {
    my ($start, $end) = $self->convert_to_local($f->{'start'}, $f->{'end'});

    my $start   = List::Util::max($start, 1);
    my $end     = List::Util::min($end, $width);
    my $cigar   = $f->{'cigar_string'};
  }
};

1;

