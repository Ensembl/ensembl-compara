package Bio::EnsEMBL::GlyphSet::marker;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
use Sanger::Graphics::Glyph::Rect;
use Sanger::Graphics::Glyph::Text;
use Sanger::Graphics::Bump;

@ISA = qw(Bio::EnsEMBL::GlyphSet);

my $MAP_WEIGHT = 2;
my $PRIORITY   = 50;

sub init_label {
  my ($self) = @_;
  return if( defined $self->{'config'}->{'_no_label'} );
  $self->label( new Sanger::Graphics::Glyph::Text({
    'text'    => "Markers",
    'font'    => 'Small',
    'absolutey' => 1,
    'href'    => qq[javascript:X=hw('@{[$self->{container}{_config_file_name_}]}','$ENV{'ENSEMBL_SCRIPT'}','markers')],
    'zmenu'   => {
    'caption'           => 'HELP',
    "01:Track information..."   => qq[javascript:X=hw(\'@{[$self->{container}{_config_file_name_}]}\',\'$ENV{'ENSEMBL_SCRIPT'}\',\'markers\')]
  }}));
}

sub _init {
  my $self = shift;

  my $slice         = $self->{'container'};
  my $Config        = $self->{'config'};
  my $L             = $slice->length();
  my $pix_per_bp    = $Config->transform->{'scalex'};
  my $bitmap_length = int($slice->length() * $pix_per_bp);
  my @bitmap;

  return unless $self->strand() == -1;

  $self->{'colours'} = $Config->get('marker','colours');
  my $fontname       = "Tiny";
  my $row_height     = 8;
  my ($w,$h)         = $Config->texthelper->px2bp($fontname);
      $w             = $Config->texthelper->width($fontname);

  my $labels         = $Config->get('marker', 'labels' ) eq 'on';

  my $priority = ($self->{container}{_config_file_name_} eq 'Homo_sapiens' ? 
                  $PRIORITY : undef);

  my @features = @{$slice->get_all_MarkerFeatures(undef,$priority,$MAP_WEIGHT)};
  foreach my $f (@features){
    my $ms           = $f->marker->display_MarkerSynonym;
    my $fid          = $ms ? $ms->name : '--';
    my $bp_textwidth = $w * length("$fid ");
    my ($feature_colour, $label_colour, $part_to_colour) = $self->colour($f);
    my $href         = "/@{[$self->{container}{_config_file_name_}]}/markerview?marker=$fid";

    my $S = $f->start()-1; next if $S>$L; $S = 0 if $S<0;
    my $E = $f->end()    ; next if $E<0;  $E = $L if $E>$L;
    $self->push( new Sanger::Graphics::Glyph::Rect({
      'x' => $S,        'y' => 0,         'height' => $row_height, 'width' => ($E-$S+1),
      'colour' => $feature_colour, 'absolutey' => 1,
      'href'   => $href, 'zmenu' => { 'caption' => ($ms && $ms->source eq 'unists' ? "uniSTS:$fid" : $fid), 'Marker info' => $href }
    }));
    next unless $labels;
    my $glyph = new Sanger::Graphics::Glyph::Text({
      'x'         => $S,
      'y'         => $row_height + 2,
      'height'    => $Config->texthelper->height($fontname),
      'width'     => $bp_textwidth,
      'font'      => $fontname,
      'colour'    => $label_colour,
      'absolutey' => 1,
      'text'      => $fid,
      'href'      => "/@{[$self->{container}{_config_file_name_}]}/markerview?marker=$fid",
    });

    my $bump_start = int($glyph->x() * $pix_per_bp);
       $bump_start = 0 if $bump_start < 0;
    my $bump_end = $bump_start + $bp_textwidth;
    next if $bump_end > $bitmap_length;
    my $row = & Sanger::Graphics::Bump::bump_row( $bump_start, $bump_end, $bitmap_length, \@bitmap );
    $glyph->y($glyph->y() + (1.2 * $row * $h));
    $self->push($glyph);
  }    

  ## No features show "empty track line" if option set....  ##
  if ((scalar(@features) == 0) && $Config->get('_settings','opt_empty_tracks')==1){
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
