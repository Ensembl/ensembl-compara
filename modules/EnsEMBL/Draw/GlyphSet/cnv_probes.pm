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

package EnsEMBL::Draw::GlyphSet::cnv_probes;

### Draw copy number variant probe track (structural variations)

use strict;

use base qw(EnsEMBL::Draw::GlyphSet_simple);

sub my_label   { return 'Copy Number Variant Probes'; }
sub colour_key { return 'cnv'; }

sub features {
  my $self   = shift; 
  my $slice  = $self->{'container'};
  my $source = $self->my_config('source');
  my $var_db = $self->my_config('db') || 'variation';
  my $svf_adaptor = $self->{'config'}->hub->get_adaptor('get_StructuralVariationFeatureAdaptor', $var_db);

  my $var_features;
  
  if ($source =~ /^\w/) {
    $var_features = $svf_adaptor->fetch_all_cnv_probe_by_Slice($slice, $source);
  } else {
    $var_features = $svf_adaptor->fetch_all_cnv_probe_by_Slice($slice);
  }
  
  return $var_features;  
}

sub href {
  my ($self, $f) = @_;
  
  my $href = $self->_url({
    type => 'StructuralVariation',
    sv   => $f->variation_name,
		svf  => $f->dbID,
    vdb  => 'variation'
  });
  
  return $href;
}

sub title {
  my ($self, $f) = @_;
  my $id     = $f->variation_name;
  my $start  = $self->{'container'}->start + $f->start -1;
  my $end    = $self->{'container'}->end + $f->end;
  my $pos    = 'Chr ' . $f->seq_region_name . ":$start-$end";
  my $source = $f->source;

  return "Copy number variation probes: $id; Source: $source; Location: $pos";
}

sub highlight {
  my ($self, $f, $composite, $pix_per_bp, $h) = @_;
 
  return unless $self->{'config'}->get_option('opt_highlight_feature') != 0;
  return unless grep $_ eq $f->variation_name, $self->highlights;
  
  # First a black box
  $self->unshift(
    $self->Rect({
      x         => $composite->x - 2 / $pix_per_bp,
      y         => $composite->y - 2, # + makes it go down
      width     => $composite->width + 4 / $pix_per_bp,
      height    => $h + 4,
      colour    => 'black',
      absolutey => 1,
    }),
		$self->Rect({ # Then a 1 pixel smaller green box
      x         => $composite->x - 1 / $pix_per_bp,
      y         => $composite->y - 1, # + makes it go down
      width     => $composite->width + 2 / $pix_per_bp,
      height    => $h + 2,
      colour    => 'green',
      absolutey => 1,
    })
  );
}

1;
