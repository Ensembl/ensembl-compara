package Bio::EnsEMBL::GlyphSet::_marker;

use strict;

use base qw(Bio::EnsEMBL::GlyphSet);

our $MAP_WEIGHT = 2;
our $PRIORITY   = 50;

sub _init {
  my $self = shift;

  return $self->render_text if $self->{'text_export'};
  
  my $slice         = $self->{'container'};
  my $Config        = $self->{'config'};

  $self->_init_bump(); ## Initialize bumping (set max depth to "infinity"! 

  my $L             = $slice->length();
  my $pix_per_bp    = $Config->transform->{'scalex'};

  return unless $self->strand() == -1;

  my( $fontname, $fontsize ) = $self->get_font_details( 'outertext' );
  my @res = $self->get_text_width( 0, 'X', '', 'font'=>$fontname, 'ptsize' => $fontsize );
  my $h = $res[3];

  my $row_height     = 8;

  my $labels         = ($self->my_config('labels' ) ne 'off') && ($L<1e7);
  if( $L > 5e7 ) {
    $self->errorTrack( "Markers only displayed for less than 50Mb.");
    return;
  }

  my $priority       = $self->my_config( 'priority' );

  my $previous_start = $L + 1e10;
  my $previous_end   = -1e10;

  my @features = sort { $a->seq_region_start <=> $b->seq_region_start }
                 @{$slice->get_all_MarkerFeatures(undef,$priority,$MAP_WEIGHT)};
  my $base_url = $self->_url( { 'action' => 'Marker' } );
  
  foreach my $f (@features){
    my $ms   = $f->marker->display_MarkerSynonym;
    my $fid  = $ms ? $ms->name : '';
      ($fid) = grep { $_ ne '-' } map { $_->name } @{$f->marker->get_all_MarkerSynonyms||[]} if $fid eq '-' || $fid eq '';

    my $feature_colour = $self->my_colour( $f->marker->type );
    my $zmenu = {
    	'type'   => 'Location',
    	'action' => 'Marker',
    	'm'      => $fid,
    };

    my $S = $f->start()-1; next if $S>$L; $S = 0 if $S<0;
    my $E = $f->end()    ; next if $E<0;  $E = $L if $E>$L;
    
    # Draw feature
    unless( $slice->strand < 0 ? $previous_start - $S < 0.5/$pix_per_bp : $E - $previous_end < 0.5/$pix_per_bp ) {
      $self->push( $self->Rect({
        'x' => $S,
        'y' => 0,
        'height' => $row_height, 
        'width' => ($E-$S+1),
        'colour' => $feature_colour, 
        'absolutey' => 1,
        'href' => $self->_url($zmenu)
      }));
      $previous_end   = $E;
      $previous_start = $E;
    }
    next unless $labels;
    my @res = $self->get_text_width( 0, $fid, '', 'font'=>$fontname, 'ptsize' => $fontsize );
    my $glyph = $self->Text({
      'x'         => $S,
      'y'         => $row_height,
      'height'    => $h,
      'width'     => $res[2] / $pix_per_bp,
      'halign'    => 'left',
      'font'      => $fontname,
      'ptsize'    => $fontsize,
      'colour'    => $feature_colour,
      'absolutey' => 1,
      'text'      => $fid,
      'href'      => $self->_url($zmenu),
    });

    my $bump_start = int($glyph->x() * $pix_per_bp);
       $bump_start = 0 if $bump_start < 0;
    my $bump_end = $bump_start + $res[2];
    my $row = $self->bump_row( $bump_start, $bump_end, 1 ); # don't display if falls off RHS.. 
    next if $row < 0;
    $glyph->y($glyph->y() + (1.2 * $row * $h));
    $self->push($glyph);
  }    
  ## No features show "empty track line" if option set....  ##
  if( (scalar(@features) == 0 ) && $Config->get_parameter( 'opt_empty_tracks')==1){
    $self->errorTrack( "No markers in this region" )
  }
}

sub render_text {
  my $self = shift;

  return unless $self->strand == -1;
  
  my $export;
  
  foreach my $f (sort { $a->seq_region_start <=> $b->seq_region_start } @{$self->{'container'}->get_all_MarkerFeatures}) {
    my $ms = $f->marker->display_MarkerSynonym;
    my $fid = $ms ? $ms->name : '';
    
    ($fid) = grep { $_ ne '-' } map { $_->name } @{$f->marker->get_all_MarkerSynonyms||[]} if $fid eq '-' || $fid eq '';    
    
    $export .= $self->_render_text($f, 'Marker', { 'headers' => [ 'id' ], 'values' => [ $fid ] });
  }
  
  return $export;
}

1;
