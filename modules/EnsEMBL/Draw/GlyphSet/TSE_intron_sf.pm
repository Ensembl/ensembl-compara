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

package EnsEMBL::Draw::GlyphSet::TSE_intron_sf;

### Draws intron supporting evidence on Transcript/SupportingEvidence

use Data::Dumper;

use strict;

use base qw(EnsEMBL::Draw::GlyphSet);

sub _init {
  my ($self) = @_;
  my $all_matches = $self->cache('align_object')->{'intron_support'};
  $self->draw_glyphs($all_matches);
}

sub draw_glyphs {
  my $self         = shift;
  my $all_matches  = shift or return;
  my $wuc          = $self->{'config'};
  my $h            = 8; #height of glyph
  my $pix_per_bp   = $wuc->transform_object->scalex;
  my( $fontname, $fontsize ) = $self->get_font_details( 'outertext' );
  my($font_w_bp, $font_h_bp) = $wuc->texthelper->px2bp($fontname);
  my $length       = $wuc->container_width(); 
  my $strand       = $wuc->cache('trans_object')->{'transcript'}->strand;
  my $legend       = $wuc->cache('legend') || {};
  my $legend_priority = 4;
  my $H               = 0;
  my $legend       = $wuc->cache('legend') || {};

  my $legend_priority = 0;
  foreach my $k (keys %$legend) {
    $legend_priority = $legend->{$k}{'priority'} > $legend_priority ? $legend->{$k}{'priority'} : $legend_priority;
  }
  $legend_priority++;

  (my @sorted_hits) = sort { $a->{'munged_start'} <=> $b->{'munged_start'} } @{$all_matches};
  if (@sorted_hits) {
    #add a spacer
    my $gap = $font_h_bp + 20;
    my $tglyph = $self->Rect({
      'x'         => 0,
      'y'         => $H,
      'height'    => $gap,
      'width'     => 10,
      'colour'    => 'white',
    });
    $self->push($tglyph);
    $H += $gap;
  }
  else {
    #let the user know there are no features
    $self->no_features;
  }

  my %hit_type_legends = (
    intron_support => 'Intron',
    intron_support_non_can => 'Intron (non-canonical)'
  );

  #go through each parsed transcript_supporting_feature
  foreach my $hit_details (@sorted_hits) {
    my $hit_name  = $hit_details->{'hit_name'};
    my $hit_start = $hit_details->{'munged_start'};
    my $hit_end = $hit_details->{'munged_end'};
    my $width = $hit_end - $hit_start;

    my $hit_type = 'intron_support';
    my $colour = $self->my_colour($hit_type);
    my $can_type = [ split(/:/,$hit_name) ]->[-1];
    my $non_canonical = 0;
    if ($can_type and length($can_type)>3 and
         substr("non canonical",0,length($can_type)) eq $can_type) {
      $hit_type .= '_non_can';
      $colour = $self->my_colour($hit_type);
      $non_canonical = 1;
    }
    my $legend_entry = $hit_type_legends{$hit_type};
    $legend->{$legend_entry}{'found'}++;
    $legend->{$legend_entry}{'priority'} = $non_canonical ? $legend_priority+1 : $legend_priority;
    $legend->{$legend_entry}{'height'}   = $h;
    $legend->{$legend_entry}{'colour'}   = $colour;
    $legend->{$legend_entry}{'style'}    = 'intron';
    

    my $zmenu_dets = {
      'type'    => 'Transcript',
      'action'  => 'IntronSupportingEvidenceAlignment',
      'score'   => $hit_details->{'score'},
      'hit_name'=> $hit_name,
    };

    my $hit = {
      'x'            => $hit_start ,
      'y'            => $H,
      'width'        => $width,
      'height'       => $h,
      'colour'       => $colour,
      'absolutey'    => 1,
      'title'        => $hit_name,
      'href'         => $self->_url($zmenu_dets),
#      'bordercolour' => $bordercolour,
    };

    my $G = $self->Rect($hit);
    $self->push( $G );
    $H += $font_h_bp + 14;

  }
  $wuc->cache('legend',$legend) if $legend;
}

sub no_features {
  my $self  = shift;
  my $label = $self->my_label;
  $self->errorTrack("No Intron supporting evidence$label for this transcript") if $label && $self->{'config'}->get_option('opt_empty_tracks') == 0;
}

1;
