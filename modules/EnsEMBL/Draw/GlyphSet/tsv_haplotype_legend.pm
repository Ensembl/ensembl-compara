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

package EnsEMBL::Draw::GlyphSet::tsv_haplotype_legend;

### Haplotype legend for Transcript/Population/Image

use strict;

use base qw(EnsEMBL::Draw::GlyphSet::legend);

sub _init {
  my ($self) = @_; 
  
  my $Config        = $self->{'config'};

  return unless $Config->{'tsv_haplotype_legend_features'}; 
  my %features = %{$Config->{'tsv_haplotype_legend_features'}};
  return unless %features;

  $self->init_legend(3);

  my $seen_any = 0;
  foreach (sort { $features{$b}->{'priority'} <=> $features{$a}->{'priority'} } keys %features) {
    $self->newline(1);
    my @colours = @{$features{$_}->{'legend'}}; 
    while( my ($legend, $colour) = splice @colours, 0, 2 ) {  
      if ($legend =~ /Label/){next;}
      my $item = {
        legend => $legend,
        colour => $colour,
        border => 'black',
      };
      if($colour eq 'stripes') {
        my $conf_colours  = $self->my_config('colours' );
        $item->{'colour'} = $conf_colours->{'same'}{'default'};
        $item->{'stripe'} = $conf_colours->{'different'}{'default'};
      }
      $self->add_to_legend($item);
      $seen_any = 1;
    }
  }

  unless( $seen_any ) {
    $self->errorTrack( "No SNPs in this panel" );
  }
}

1;
      
