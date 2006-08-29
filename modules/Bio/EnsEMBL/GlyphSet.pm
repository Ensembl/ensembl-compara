package Bio::EnsEMBL::GlyphSet;
use strict;
use Exporter;
use Sanger::Graphics::GlyphSet;
use Sanger::Graphics::Glyph::Rect;
use Sanger::Graphics::Glyph::Text;
use Bio::EnsEMBL::Utils::Eprof qw(eprof_start eprof_end eprof_dump);
use GD;
use GD::Text;
use CGI qw(escapeHTML);

use vars qw(@ISA $AUTOLOAD);

@ISA=qw(Sanger::Graphics::GlyphSet);
our %cache;

#########
# constructor
#

sub get_font_details {
  my( $self, $type ) = @_;
  my $ST = $self->{'config'}->species_defs->ENSEMBL_STYLE;
  return (
    $type =~ /fixed/i ? $ST->{'GRAPHIC_FONT_FIXED'} : $ST->{'GRAPHIC_FONT'},
    $ST->{'GRAPHIC_FONTSIZE'} * ($ST->{'GRAPHIC_'.uc($type)}||1)
  );
}

sub init_label_text {
  my( $self, $text, $help_link, $description) = @_;
  return if defined $self->{'config'}->{'_no_label'};
  my @extra=();
  if( $help_link ) {
    push @extra,
      'href'      => qq[javascript:X=hw('@{[$self->{container}{_config_file_name_}]}','$ENV{'ENSEMBL_SCRIPT'}','$help_link')],
      'zmenu'     => { 'caption' => 'HELP', '02:Track information...' => qq[javascript:X=hw(\'@{[$self->{container}{_config_file_name_}]}\',\'$ENV{'ENSEMBL_SCRIPT'}\',\'$help_link\')] };
  }
  if( $description ) {
    push @extra, '01:'.CGI::escapeHTML( $description ) => '';
  }
  
  my $ST = $self->{'config'}->species_defs->ENSEMBL_STYLE;
  my $font = $ST->{'GRAPHIC_FONT'};
  my $fsze = $ST->{'GRAPHIC_FONTSIZE'} * $ST->{'GRAPHIC_LABEL'};

  my @res = $self->get_text_width(0,$text,'','font'=>$font,'ptsize'=>$fsze);
  $self->label( new Sanger::Graphics::Glyph::Text({
    'text'   => "$text",
    'font'   => $font,
    'ptsize' => $fsze,
    @extra,
    'absolutey'=>1,'height'=>$res[3]}
  ));
}

sub species_defs { return $_[0]->{'config'}->{'species_defs'}; }

sub get_text_width {
  my( $self, $width, $text, $short_text, %parameters ) = @_;

  my $KEY;
  if($parameters{'font'} =~ /Cour/i && length($text)==1 ) {
    $KEY = "$width--X--$short_text--$parameters{'font'}--$parameters{'ptsize'}";
  } else {
    $KEY = "$width--$text--$short_text--$parameters{'font'}--$parameters{'ptsize'}";
  }
  return @{$cache{$KEY}} if exists $cache{$KEY};
## return @{$self->{'_cache_'}{$KEY}} if exists $self->{'_cache_'}{$KEY};
  my $font   = $self->{'config'}->species_defs->ENSEMBL_STYLE->{'GRAPHIC_TTF_PATH'}.($parameters{'font'}||'arial').'.ttf';
  $width ||= 1e6;
  my $ptsize =  $parameters{'ptsize'}||10;
  my $gd_text = GD::Text->new();
  eval {
    if( -e $font ) {
      $gd_text->set_font( $font, $ptsize );
    } elsif( $parameters{'font'} eq 'Tiny' ) {
      $gd_text->set_font( gdTinyFont );
    } elsif( $parameters{'font'} eq 'Small' ) {
      $gd_text->set_font( gdSmallFont );
    } elsif( $parameters{'font'} eq 'MediumBold' ) {
      $gd_text->set_font( gdMediumBoldFont );
    } elsif( $parameters{'font'} eq 'Large' ) {
      $gd_text->set_font( gdLargeFont );
    } elsif( $parameters{'font'} eq 'Giant' ) {
      $gd_text->set_font( gdGiantFont );
    }
  };

  warn $@ if $@;
  if( $gd_text ) {
    if($font =~ /Cour/i && length($text)==1) {
      $gd_text->set_text('X');
    } else {
      $gd_text->set_text($text);
    }
    my($w,$h) = $gd_text->get('width','height');
    my @res;
    if($w<$width) { 
      @res = ($text,      'full', $w,$h);
    } elsif($short_text) {
      $gd_text->set_text($short_text);
      ($w,$h) = $gd_text->get('width','height');
      if($w<$width) { 
        @res = ($short_text,'short',$w,$h);
      } else {
        @res = ('',         'none', 0, 0 );
      }
    }
    $self->{'_cache_'}{$KEY} = \@res;
    $cache{$KEY} = \@res;
    return @res;
  }
}

sub commify { local $_ = reverse $_[1]; s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g; return scalar reverse $_; }
sub slice2sr {
  my( $self, $s, $e ) = @_;

  return $self->{'container'}->strand < 0 ?
    ( $self->{'container'}->end   - $e + 1 , $self->{'container'}->end   - $s + 1 ) : 
    ( $self->{'container'}->start + $s - 1 , $self->{'container'}->start + $e - 1 );
}

sub sr2slice {
  my( $self, $s, $e ) = @_;

  return $self->{'container'}->strand < 0 ?
    (   $self->{'container'}->end   - $e + 1 ,   $self->{'container'}->end   - $s + 1 ) :
    ( - $self->{'container'}->start + $s + 1 , - $self->{'container'}->start + $e + 1 );
}

sub new {
  my $class = shift;
  if(!$class) {
    warn( "EnsEMBL::GlyphSet::failed at: ".gmtime()." in /$ENV{'ENSEMBL_SPECIES'}/$ENV{'ENSEMBL_SCRIPT'}" );
    warn( "EnsEMBL::GlyphSet::failed with a call of new on an undefined value" );
    return undef;
  }
  my $self = $class->SUPER::new( @_ );
  $self->{'bumpbutton'} = undef;
  return $self;
}

sub __init {
  my $self = shift;
  eprof_start('init_'.ref($self));
  $self->_init(@_);
  eprof_end('init_'.ref($self));
}
sub bumpbutton {
    my ($self, $val) = @_;
    $self->{'bumpbutton'} = $val if(defined $val);
    return $self->{'bumpbutton'};
}

sub label2 {
    my ($self, $val) = @_;
    $self->{'label2'} = $val if(defined $val);
    return $self->{'label2'};
}

sub my_config {
  my( $self, $key ) = @_;
  return $self->{'_my_config_'}{ $key } ||= $self->{'config'}->get($self->check(), $key );
}

sub set_my_config {
  my( $self, $key, $val ) = @_;
  $self->{'config'}->set($self->check(), $key, $val, 1);
  $self->{'_my_config_'}{ $key } = $val;
  return $self->{'_my_config_'}{$key};
}

sub check {
  my( $self ) = @_;
  unless( $self->{'_check_'} ) {
    my $feature_name = ref $self;
    if( exists( $self->{'extras'}{'config_key'} ) ) {
      $feature_name =  $self->{'extras'}{'config_key'} ;
    } else {
      $feature_name =~s/.*:://;
    }
    $self->{'_check_'} = $self->{'config'}->is_available_artefact( $feature_name ) ? $feature_name : undef ;
  }
  return $self->{'_check_'};
}

## Stuff copied out of scalebar.pm so that contig.pm can use it!

sub HASH_URL {
  my($self,$db,$hash) = @_;
  return "/@{[$self->{container}{_config_file_name_}]}/r?d=$db;".join ';', map { "$_=$hash->{$_}" } keys %{$hash||{}};
}

sub ID_URL {
  my($self,$db,$id) = @_;
  return undef unless $self->species_defs;
  return undef if $db eq 'NULL';
  return exists( $self->species_defs->ENSEMBL_EXTERNAL_URLS->{$db}) ? "/@{[$self->{container}{_config_file_name_}]}/r?d=$db;ID=$id" : "";
}

sub zoom_URL {
  my( $self, $PART, $interval_middle, $width, $factor, $highlights, $config_number, $ori) = @_;
  my $extra;
  if( $config_number ) {
    $extra = "o$config_number=c$config_number=$PART:$interval_middle:$ori;w$config_number=$width"; 
  } else {
    $extra = "c=$PART:$interval_middle;w=$width";
  }
  return qq(/$ENV{'ENSEMBL_SPECIES'}/$ENV{'ENSEMBL_SCRIPT'}?$extra$highlights);
}

sub zoom_zoom_zmenu {
  my ($self, $chr, $interval_middle, $width, $highlights, $zoom_width, $config_number, $ori) = @_;
  $chr =~s/.*=//;
  return qq(zz('/$ENV{'ENSEMBL_SPECIES'}/$ENV{'ENSEMBL_SCRIPT'}', '$chr', '$interval_middle', '$width', '$zoom_width', '$highlights','$ori','$config_number', '@{[$self->{container}{_config_file_name_}]}'));
}
sub zoom_zmenu {
  my ($self, $chr, $interval_middle, $width, $highlights, $config_number, $ori ) = @_;
  $chr =~s/.*=//;
  return qq(zn('/$ENV{'ENSEMBL_SPECIES'}/$ENV{'ENSEMBL_SCRIPT'}', '$chr', '$interval_middle', '$width', '$highlights','$ori','$config_number', '@{[$self->{container}{_config_file_name_}]}' ));
}

sub draw_cigar_feature {
  my( $self, $Composite, $f, $h, $feature_colour, $delete_colour, $pix_per_bp, $DO_NOT_FLIP ) = @_;
## Find the 5' end of the feature.. (start if on forward strand of forward feature....)
  #return unless $f;
  my $Q = ref($f); $Q="$Q";
    if($Q eq '') { warn("DRAWINGCODE_CIGAR < $f > ",$self->label->text," not a feature!"); }
    if($Q eq 'SCALAR') { warn("DRAWINGCODE_CIGAR << ",$$f," >> ",$self->label->text," not a feature!"); }
    if($Q eq 'HASH') { warn("DRAWINGCODE_CIGAR { ",join( "; ", keys %$f)," }  ",$self->label->text," not a feature!"); }
    if($Q eq 'ARRAY') { warn("DRAWINGCODE_CIGAR [ ", join( "; ", @$f ), " ] ",$self->label->text," not a feature!"); }
  my $S = (my $O = $DO_NOT_FLIP ? 1 : $self->strand ) == 1 ? $f->start : $f->end;
  my $length = $self->{'container'}->length;
  my @delete;

  my $cigar;
  eval { $cigar = $f->cigar_string; };
  if($@ || !$cigar) {
    my($s,$e) = ($f->start,$f->end);
    $s = 1 if $s<1;
    $e = $length if $e>$length; 
    $Composite->push(new Sanger::Graphics::Glyph::Rect({
      'x'          => $s-1,            'y'          => 0,
      'width'      => $e-$s+1,         'height'     => $h,
      'colour'     => $feature_colour, 'absolutey'  => 1,
    }));
    return;
  }

## Parse the cigar string, splitting up into an array
## like ('10M','2I','30M','I','M','20M','2D','2020M');
## original string - "10M2I30MIM20M2D2020M"
  foreach( $f->cigar_string=~/(\d*[MDI])/g ) {
## Split each of the {number}{Letter} entries into a pair of [ {number}, {letter} ] 
## representing length and feature type ( 'M' -> 'Match/mismatch', 'I' -> Insert, 'D' -> Deletion )
## If there is no number convert it to [ 1, {letter} ] as no-number implies a single base pair...
    my ($l,$type) = /^(\d+)([MDI])/ ? ($1,$2):(1,$_);
## If it is a D (this is a deletion) and so we note it as a feature between the end
## of the current and the start of the next feature...
##                      ( current start, current start - ORIENTATION )
## otherwise it is an insertion or match/mismatch
##  we compute next start sa ( current start, next start - ORIENTATION ) 
##  next start is current start + (length of sub-feature) * ORIENTATION 
    my $s = $S;
    my $e = ( $S += ( $type eq 'D' ? 0 : $l*$O ) ) - $O;
## If a match/mismatch - draw box....
    if($type eq 'M') {
      ($s,$e) = ($e,$s) if $s>$e;      ## Sort out flipped features...
      next if $e < 1 || $s > $length;  ## Skip if all outside the box...
      $s = 1       if $s<1;            ## Trim to area of box...
      $e = $length if $e>$length;

      $Composite->push(new Sanger::Graphics::Glyph::Rect({
        'x'          => $s-1,            'y'          => 0, 
        'width'      => $e-$s+1,         'height'     => $h,
        'colour'     => $feature_colour, 'absolutey'  => 1,
      }));
## If a deletion temp store it so that we can draw after all matches....
    } elsif($type eq 'D') {
      ($s,$e) = ($e,$s) if $s<$e;
      next if $e < 1 || $s > $length || $pix_per_bp < 1 ;  ## Skip if all outside box
      push @delete, $e;
    }
  }

## Draw deletion markers....
  foreach (@delete) {
    $Composite->push(new Sanger::Graphics::Glyph::Rect({
      'x'          => $_,              'y'          => 0, 
      'width'      => 0,               'height'     => $h,
      'colour'     => $delete_colour,  'absolutey'  => 1,
    }));
  }
}

sub no_features {
  my $self = shift;
  $self->errorTrack( "No ".$self->my_label." in this region" ) if $self->{'config'}->get('_settings','opt_empty_tracks')==1;
}

sub thousandify {
  my( $self, $value ) = @_;
  local $_ = reverse $value;
  s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
  return scalar reverse $_;
}


sub errorTrack {
  my ($self, $message, $x, $y) = @_;
  my $ST = $self->{'config'}->species_defs->ENSEMBL_STYLE;
  my $font = $ST->{'GRAPHIC_FONT'};
  my $fsze = $ST->{'GRAPHIC_FONTSIZE'} * $ST->{'GRAPHIC_TEXT'};
  my @res = $self->get_text_width( 0, $message, '', $font, $fsze );

  my $length = $self->{'config'}->image_width();
  $self->push( new Sanger::Graphics::Glyph::Text({
    'x'         => $x || int(($length - $res[2])/2 ),
    'y'         => $y || 2,
    'width'     => $res[2],
    'textwidth'     => $res[2],
    'height'    => $res[3],
    'halign'    => 'center',
    'font'      => $font,
    'ptsize'    => $fsze,
    'colour'    => "red",
    'text'      => $message,
    'absolutey' => 1,
    'absolutex' => 1,
    'absolutewidth' => 1,
    'pixperbp'  => $self->{'config'}->{'transform'}->{'scalex'} ,
  }) );

    return;
}

1;
