=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Draw::GlyphSet::_variation;

### Draws a SNP track

use strict;

use List::Util qw(min);

use Bio::EnsEMBL::Variation::Utils::Constants;
use Bio::EnsEMBL::Variation::VariationFeature;

use base qw(EnsEMBL::Draw::GlyphSet_simpler);

sub depth {
  my $self   = shift;
  my $length = $self->{'container'}->length;

  if ($self->{'display'} =~ /labels/ || ($self->{'display'} eq 'normal' && $length <= 2e5) || $length <= 101) {
    return $length > 1e4 ? 20 : undef;
  }
  
  return $self->SUPER::depth;
}

sub label_overlay { return 1; }

sub render_labels {
  my ($self, $labels) = @_;
  $self->{'show_labels'} = 1 if $self->{'container'}->length <= 1e4;
  return $self->render_normal;
}

sub _init {
  my $self = shift;
  $self->{'my_config'}->set('no_label', 1) unless $self->{'show_labels'};
  return $self->SUPER::_init(@_);
}

sub my_label { 
  my $self  = shift;  
  my $label = $self->type =~ /somatic/ ? 'Somatic Mutations' : 'Variations'; 
  return $label; 
}

sub features {
  my $self         = shift;
  my $max_length   = $self->my_config('threshold') || 1000;
  my $slice_length = $self->{'container'}->length;

  my $hub = $self->{'config'}{'hub'};  

  #$self->{'legend'}{'variation_legend'}{$_->display_consequence} ||= $self->get_colours($_)->{'feature'} for @$snps;
  
  if ($slice_length > $max_length * 1010) {
    $self->errorTrack("Variation features are not displayed for regions larger than ${max_length}Kb");
    return [];
  } else {
    my $features_list = $hub->get_query('Variation')->go_variation($self,{
      species => $hub->species,
      slice => $self->{'container'},
      id => $self->{'my_config'}->id,
      config => [qw(filter source sources sets set_name style no_label)],
      var_db => $self->my_config('db') || 'variation',
      config_type => $self->{'config'}{'type'},
      type => $self->type,
    });
    if (!scalar(@$features_list)) {
      my $track_name = $self->my_config('name'); 
      $self->errorTrack("No $track_name data for this region");
      return [];
    }
    else {
      return $features_list;
    }
  }
}

sub render_tag {
  my ($self, $tag, $composite, $slice_length, $height, $start, $end) = @_;
  my $pix_per_bp = $self->scalex;
  my @glyph;
  my %font = $self->get_font_details($self->my_config('font') || 'innertext', 1);

  if ($tag->{'style'} eq 'insertion') {
    push @glyph, $self->Triangle({
      mid_point  => [ $start - 1, $height - 1 ],
      colour     => $tag->{'colour'},
      absolutey  => 1,
      width      => 4 / $pix_per_bp,
      height     => 3,
      direction  => 'up',
    });
    
    my $width = min(1, 16 / $pix_per_bp);
    
    # invisible box to make inserts more clickable
    $composite->push($self->Rect({
      x         => $start - 1 - $width / 2,
      y         => 0,
      absolutey => 1,
      width     => $width,
      height    => $height + 2,
      href      => $tag->{'href'}
    }));
  } elsif ($start <= $tag->{'start'}) {
    my $box_width = 8 / $pix_per_bp;
    
    if ($tag->{'style'} eq 'box') {
      my (undef, undef, $text_width, $text_height) = $self->get_text_width(0, $tag->{'letter'}, '', %font);
      my $width  = $text_width / $pix_per_bp;
      my $box_x  = $start - 4 / $pix_per_bp;
      my $text_x = $box_width < $width ? $box_x : $start + 0.5 - ($width / 2);
      
      $composite->push($self->Rect({
        x         => $box_x - 0.5,
        y         => 0,
        width     => $box_width,
        height    => $height,
        colour    => $tag->{'colour'},
        absolutey => 1
      }), $self->Text({
        x         => $text_x,
        y         => ($height - $text_height) / 2,
        width     => $width,
        textwidth => $text_width,
        height    => $text_height,
        halign    => 'center',
        colour    => $tag->{'label_colour'},
        text      => $tag->{'letter'},
        absolutey => 1,
        %font
      }));
    } elsif ($tag->{'style'} =~ /^(delta|left-snp)$/) {
      push @glyph, $self->Triangle({
        mid_point => [ $start - 0.5, $tag->{'style'} eq 'delta' ? $height : 0 ],
        colour    => $tag->{'colour'},
        absolutey => 1,
        width     => $box_width,
        height    => $height,
        direction => $tag->{'style'} eq 'delta' ? 'down' : 'up',
      });
      
      # invisible box to make inserts more clickable
      $composite->push($self->Rect({
        x         => $start - 1 - $box_width / 2,
        y         => 0,
        absolutey => 1,
        width     => $box_width,
        height    => $height,
      }));
    }
  }
  
  if ($tag->{'style'} eq 'label') {
    my $text_width = [$self->get_text_width(0, $tag->{'label'}, '', %font)]->[2];
    
    $composite->push($self->Text({
      x         => $tag->{'start'},
      y         => 0,
      height    => $height,
      textwidth => $text_width,
      width     => $text_width / $pix_per_bp,
      halign    => 'left',
      colour    => $tag->{'colour'},
      text      => $tag->{'label'},
      absolutey => 1,
      %font
    }));
  }
  
  return @glyph;
}

sub highlight {
  my $self = shift; 
  my ($f, $composite, $pix_per_bp, $h, $hi_colour) = @_;
  my %highlights = map { $_ => 1 } $self->highlights;

  if ($self->{'config'}->core_object('variation')){
    my $var_id = $self->{'config'}->core_object('variation')->name;
       $var_id =~ s/rs//;
       
    $highlights{$var_id} = 1;
  }

  # Are we going to highlight self item
  my $id = $f->{'variation_name'};  
     $id =~ s/^rs//;
 
  return unless $self->{'config'}->get_option('opt_highlight_feature') != 0 && ($highlights{$id} || $highlights{"rs$id"});
  
  $composite->z(20);
  
  my $z = $f->{'start'} > $f->{'end'} ? 0 : 18;
  
  foreach (@{$composite->{'composite'}}) {
    $self->unshift($self->Rect({
      x      => $composite->x + $_->x - 2 / $pix_per_bp,
      y      => $composite->y + $_->y - 2,
      width  => $_->width  + 4 / $pix_per_bp,
      height => $_->height + 4,
      colour => 'black',
      z      => $z,
    }));
  }
}

sub export_feature {
  my $self = shift;
  my ($feature) = @_;
  
  my $variation_name = $feature->variation_name;
  
  return if $self->{'export_cache'}{"variation:$variation_name"};
  
  $self->{'export_cache'}{"variation:$variation_name"} = 1;
  
  return $self->_render_text($feature, 'Variation', { 
    headers => [ 'variation_name', 'alleles', 'class', 'type' ],
    values  => [ $variation_name, $feature->allele_string, $feature->var_class, $feature->display_consequence ]
  });
}

sub supports_subtitles { return 1; }

1;
