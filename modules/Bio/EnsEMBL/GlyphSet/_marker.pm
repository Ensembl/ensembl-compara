package Bio::EnsEMBL::GlyphSet::_marker;
use strict;
use vars qw(@ISA);

use Sanger::Graphics::Bump;

use base qw(Bio::EnsEMBL::GlyphSet);

my $MAP_WEIGHT = 2;
my $PRIORITY   = 50;

sub init_label {
  my ($self) = @_;
  return if( defined $self->{'config'}->{'_no_label'} );
  $self->init_label_text('Markers','markers');
}

sub _init {
  my $self = shift;

  my $slice         = $self->{'container'};
  my $Config        = $self->{'config'};
  return unless ( $Config->_is_available_artefact( 'database_tables ENSEMBL_DB.marker_feature' ) );

  $self->_init_bump(); ## Initialize bumping (set max depth to "infinity"! 

  my $L             = $slice->length();
  my $pix_per_bp    = $Config->transform->{'scalex'};
  my $bitmap_length = int($slice->length() * $pix_per_bp);
  my @bitmap;

  return unless $self->strand() == -1;

  $self->{'colours'} = $Config->get('marker','colours');
  my( $fontname, $fontsize ) = $self->get_font_details( 'outertext' );
  my @res = $self->get_text_width( 0, 'X', '', 'font'=>$fontname, 'ptsize' => $fontsize );
  my $h = $res[3];
  my $pix_per_bp = $self->{'config'}->transform()->{'scalex'};

  my $row_height     = 8;

  my $labels         = ($Config->get('marker', 'labels' ) eq 'on') && ($L<1e7);
  if( $L > 5e7 ) {
    $self->errorTrack( "Markers only displayed for less than 50Mb.");
    return;
  }

  my $priority = ($self->{container}{_config_file_name_} eq 'Homo_sapiens' ? $PRIORITY : undef);

  my $previous_start = $L + 1e9;
  my $previous_end   = -1e9 ;

  my @features = sort { $a->seq_region_start <=> $b->seq_region_start } @{$slice->get_all_MarkerFeatures(undef,$priority,$MAP_WEIGHT)};
  foreach my $f (@features){
    my $ms           = $f->marker->display_MarkerSynonym;
    my $fid          = '';
    if( $ms ) {
      $fid = $ms->name;
    }

    if( $fid eq '-' || $fid eq '' ) {
      $fid ='';
      my @mss = grep { $_->name ne '-' } @{$f->marker->get_all_MarkerSynonyms||[]};
      if(@mss) { $fid = $mss[0]->name; }
    }
    my ($feature_colour, $label_colour, $part_to_colour) = $self->colour($f);
    my $href         = "/@{[$self->{container}{_config_file_name_}]}/markerview?marker=$fid";

	    my $S = $f->start()-1; next if $S>$L; $S = 0 if $S<0;
    my $E = $f->end()    ; next if $E<0;  $E = $L if $E>$L;
    my %HREF = ();
    my %ZMENU = ();
    if($fid) {
      %HREF = ( 'href'   => $href );
      %ZMENU = ( 'zmenu' => { 'caption' => ($ms && $ms->source eq 'unists' ? "uniSTS:$fid" : $fid), 'Marker info' => $href } );
    }
    unless( $slice->strand < 0 ? $previous_start - $S < 0.5/$pix_per_bp : $E - $previous_end < 0.5/$pix_per_bp ) {
      $self->push( $self->Rect({
        'x' => $S,        'y' => 0,         'height' => $row_height, 'width' => ($E-$S+1),
        'colour' => $feature_colour, 'absolutey' => 1,
        %HREF, %ZMENU
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
      'colour'    => $label_colour,
      'absolutey' => 1,
      'text'      => $fid,
      %HREF, %ZMENU
    });

    my $bump_start = int($glyph->x() * $pix_per_bp);
       $bump_start = 0 if $bump_start < 0;
    my $bump_end = $bump_start + $res[2];
    next if $bump_end > $bitmap_length;
    my $row = $self->bump_row( $bump_start, $bump_end, 1 ); # don't display if falls off RHS.. 
    next if $row < 0;
    $glyph->y($glyph->y() + (1.2 * $row * $h));
    $self->push($glyph);
  }    
  ## No features show "empty track line" if option set....  ##
  if( (scalar(@features) == 0 ) && $Config->get('_settings','opt_empty_tracks')==1){
    $self->errorTrack( "No markers in this region" )
  }

}

sub colour {
  my ($self, $f) = @_;
  my $type = $f->marker->type;
     $type = '' unless(defined($type));
  my $col = $self->{'colours'}->{"$type"};
  return $col, $col, '';
}

1;
