package Bio::EnsEMBL::GlyphSet;
use strict;
use Exporter;
use Sanger::Graphics::GlyphSet;
use Sanger::Graphics::Glyph::Rect;
use Sanger::Graphics::Glyph::Text;
use Bio::EnsEMBL::Glyph::Symbol::line;
use Bio::EnsEMBL::Utils::Eprof qw(eprof_start eprof_end eprof_dump);
use GD;
use GD::Text;
use CGI qw(escapeHTML escape);

use vars qw(@ISA $AUTOLOAD);

@ISA=qw(Sanger::Graphics::GlyphSet);
our %cache;

#########
# constructor
#

sub _url {
  my $self = shift;
  my $params  = shift || {};
  my $species = exists( $params->{'species'} ) ? $params->{'species'} : $self->{'container'}{'_config_file_name_'};
  my $type    = exists( $params->{'type'}    ) ? $params->{'type'}    : $ENV{'ENSEMBL_TYPE'};
  my $action  = exists( $params->{'action'}  ) ? $params->{'action'}  : $ENV{'ENSEMBL_ACTION'};

  my %pars = %{$self->{'config'}{_core}{'parameters'}};
  if( $params->{'g'} && $params->{'g'} ne $pars{'g'} ) {
    delete($pars{'t'});
  }
  foreach( keys %$params ) {
    $pars{$_} = $params->{$_} unless $_ eq 'species' || $_ eq 'type' || $_ eq 'action';
  }
  my $URL = sprintf( '/%s/%s/%s', $species, $type, $action );
  my $join = '?';
## Sort the keys so that the URL is the same for a given set of parameters...
  foreach ( sort keys %pars ) {
    $URL .= sprintf '%s%s=%s', $join, escapeHTML($_), escapeHTML($pars{$_}) if defined $pars{$_};
    $join = ';';
  }
  return $URL;
}

sub get_font_details {
  my( $self, $type ) = @_;
  my $ST = $self->{'config'}->species_defs->ENSEMBL_STYLE;
  return (
    $type =~ /fixed/i ? $ST->{'GRAPHIC_FONT_FIXED'} : $ST->{'GRAPHIC_FONT'},
    $ST->{'GRAPHIC_FONTSIZE'} * ($ST->{'GRAPHIC_'.uc($type)}||1)
  );
}

sub init_label_text {
  my( $self, $text, $help_link, $zmenu) = @_;
  return if defined $self->{'config'}->{'_no_label'};
  my $href;
  
  if( $help_link ) {
      $zmenu ||= {}; 
      $zmenu->{ '02:Track information...'} = qq(javascript:X=hw('@{[$self->{container}{_config_file_name_}]}','$ENV{'ENSEMBL_SCRIPT'}','$help_link'));
  }
  if ($zmenu) {
    $zmenu->{'caption'} ||= 'HELP';
  }
  
  my $ST = $self->{'config'}->species_defs->ENSEMBL_STYLE;
  my $font = $ST->{'GRAPHIC_FONT'};
  my $fsze = $ST->{'GRAPHIC_FONTSIZE'} * $ST->{'GRAPHIC_LABEL'};

  my @res = $self->get_text_width(0,$text,'','font'=>$font,'ptsize'=>$fsze);
  $self->label( new Sanger::Graphics::Glyph::Text({
    'text'   => "$text",
    'font'   => $font,
    'ptsize' => $fsze,
    'href' => $help_link ? qq[javascript:X=hw('@{[$self->{container}{_config_file_name_}]}','$ENV{'ENSEMBL_SCRIPT'}','$help_link')] : '',
    'zmenu' => $zmenu ? $zmenu : undef,
    'colour' => $self->{'label_colour'},
    'absolutey'=>1,'height'=>$res[3]}
  ));
}

sub species_defs { return $_[0]->{'config'}->{'species_defs'}; }

sub get_text_width {
  my( $self, $width, $text, $short_text, %parameters ) = @_;

  # Adjust the text for courier fonts
  if( length($text)==1 && $parameters{'font'} =~ /Cour/i ){ $text = 'X' }

  # Look in the cache for a previous entry 
  my $KEY = "$width--$text--$short_text--"
      . "$parameters{'font'}--$parameters{'ptsize'}";
  return @{$cache{$KEY}} if exists $cache{$KEY};

  # Get the GD::Text object for this font/size
  my $gd_text = $self->get_gd_text($parameters{'font'},$parameters{'ptsize'})
      || return(); # Ensure we have the text obj

  # Use the text object to determine height/width of the given text;
  $gd_text->set_text($text);
  $width ||= 1e6; # Make initial width very big by default
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
  $self->{'_cache_'}{$KEY} = \@res; # Update the cache
  $cache{$KEY} = \@res;
  return @res;
}

sub get_gd_text{
  ### Returns the GD::Text object appropriate for the given fontname
  ### and fontsize. GD::Text objects are cached against fontname and fontsize.
  my $self   = shift;
  my $font   = shift || 'arial';
  my $ptsize = shift || 10;

  my $FONT_KEY = "${font}--${ptsize}"; 
  return $cache{$FONT_KEY} if exists( $cache{$FONT_KEY} );
  
  my $fontpath 
      = $self->{'config'}->species_defs->ENSEMBL_STYLE->{'GRAPHIC_TTF_PATH'}
        . '/' . $font . '.ttf';
  my $gd_text = GD::Text->new();
  eval {
    if( -e $fontpath ) {
      $gd_text->set_font( $font, $ptsize );
    } elsif( $font eq 'Tiny' ) {
      $gd_text->set_font( gdTinyFont );
    } elsif( $font eq 'MediumBold' ) {
      $gd_text->set_font( gdMediumBoldFont );
    } elsif( $font eq 'Large' ) {
      $gd_text->set_font( gdLargeFont );
    } elsif( $font eq 'Giant' ) {
      $gd_text->set_font( gdGiantFont );
    } else {
      $font = 'Small';
      $gd_text->set_font( gdSmallFont );
    }
  };
  warn $@ if $@;

  $cache{$FONT_KEY} = $gd_text; # Update font cache
  
  return $cache{$FONT_KEY};
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
  my $track = $self->check();
  eprof_start('DRAW:'.$track);
  $self->_init(@_);
  eprof_end('DRAW:'.$track);
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

    return $res[3];
}


sub get_featurestyle {
  my ($self, $f, $configuration) = @_;
  my $style;
  if($configuration->{'use_style'}) {
    $style = $configuration->{'styles'}{$f->das_type_category}{$f->das_type_id};
    $style ||= $configuration->{'styles'}{'default'}{$f->das_type_id};
    $style ||= $configuration->{'styles'}{$f->das_type_category}{'default'};
    $style ||= $configuration->{'styles'}{'default'}{'default'};
  }
  $style ||= {};
  $style->{'attrs'} ||= {};

  # Set some defaults
  my $colour = $style->{'attrs'}{'fgcolor'} || $configuration->{'colour'} || $configuration->{'color'} || 'blue';
  $style->{'attrs'}{'height'} ||= $configuration->{'h'};
  $style->{'attrs'}{'colour'} ||= $colour;
  return $style;
}


sub get_featuredata {
  my ($self, $f, $configuration, $y_offset) = @_;

  # keep within the window we're drawing
  my $START = $f->das_start() < 1 ? 1 : $f->das_start();
  my $END   = $f->das_end()   > $configuration->{'length'}  ? $configuration->{'length'} : $f->das_end();
  my $row_height = $configuration->{'h'};

  # truncation flags
  my $trunc_start = ($START ne $f->das_start()) ? 1 : 0;
  my $trunc_end   = ($END ne $f->das_end())        ? 1 : 0;
  my $orientation = $f->das_orientation;

  my $featuredata = {
    'row_height'    => $row_height,
    'start'         => $START,
    'end'           => $END ,
    'pix_per_bp'    => $self->{'pix_per_bp'},
    'y_offset'      => $y_offset,
    'trunc_start'   => $trunc_start,
    'trunc_end'     => $trunc_end,
    'orientation'   => $orientation,
  };
  return $featuredata;
}


sub get_symbol {
  my ($self, $style, $featuredata, $y_offset) = @_;
  my $styleattrs = $style->{'attrs'};
  my $glyph_symbol = $style->{'glyph'} || 'box';

  # Load the glyph symbol module that we need to draw this style
  $glyph_symbol = 'Bio::EnsEMBL::Glyph::Symbol::'.$glyph_symbol;
  unless ($self->dynamic_use($glyph_symbol)){
    $glyph_symbol = 'Bio::EnsEMBL::Glyph::Symbol::box';
  }
  return $glyph_symbol->new($featuredata, $styleattrs);
}

# Function will display DAS features with variable y-offset depending on SCORE attribute
# Similar to tiling array but allows for multiple types to be drawn side-by side 
# when 2 or more features are merged due to resolution the highest score will be used to determine the feature height

sub RENDER_plot{
  my( $self, $configuration ) = @_;

  my @features = sort { $a->das_score <=> $b->das_score  } @{$configuration->{'features'}};
  return unless @features;

  my ($min_score, $max_score) = ($features[0]->das_score || 0, $features[-1]->das_score || 0);
  my $style;

  my $row_height = $configuration->{'h'} || 30;

  my $pix_per_score = (abs($max_score) >  abs($min_score) ? abs($max_score) : abs($min_score)) / $row_height;
  $pix_per_score ||= 1;

  my $bp_per_pix = 1 / $self->{pix_per_bp};
  $configuration->{h} = $row_height;

  my ($gScore, $gWidth, $fCount, $gStart, $mScore) = (0, 0, 0, 0, $min_score);

# Draw the axis
  $self->push( new Sanger::Graphics::Glyph::Line({
    'x'         => 0,
    'y'         => $row_height + 1,
    'width'     => $configuration->{'length'},
    'height'    => 0,
    'absolutey' => 1,
    'colour'    => 'black',
    'dotted'    => 1,
  }));

  $self->push( new Sanger::Graphics::Glyph::Line({
    'x'         => 0,
    'y'         => 0,
    'width'     => 0,
    'height'    => $row_height * 2 + 1,
    'absolutey' => 1,
    'absolutex' => 1,
    'colour'    => 'black',
    'dotted'    => 1,
  }));

  $self->push( new Sanger::Graphics::Glyph::Text({
    'text'      => $max_score,
    'height'    => $self->{'textheight_i'},
    'font'      => $self->{'fontname_i'},
    'ptsize'    => $self->{'fontsize_i'},
    'halign'    => 'left',
    'colour'    => 'black',
    'y'         => 1,
    'x'         => 3,
    'absolutey' => 1,
    'absolutex' => 1,
  }) );


  my $pX = -1;
  my $pY = -1;

  foreach my $f (sort { ($a->das_type cmp $b->das_type) * 10 + ($a->das_start <=> $b->das_start)} @features) {
    my $START = $f->das_start() < 1 ? 1 : $f->das_start();
    my $END   = $f->das_end()   > $configuration->{'length'}  ? $configuration->{'length'} : $f->das_end();
    my $width = ($END - $START +1);
    my $score = $f->das_score || 0;

    my $Composite = new Sanger::Graphics::Glyph::Composite({
      'y'         => 0,
      'x'         => $START-1,
      'absolutey' => 1,
    });
    my $height = abs($score) / $pix_per_score;
    my $y_offset =     ($score > 0) ?  $row_height - $height : $row_height+2;
    $y_offset-- if (! $score);
#warn  join (' * ', $START, $score, $y_offset, "\n");
    my $zmenu = $self->zmenu( $f );
    $Composite->{'zmenu'} = $zmenu;

    # make clickable box to anchor zmenu
    $Composite->push( new Sanger::Graphics::Glyph::Space({
      'x'         => $START - 1,
      'y'         => ($score ? (($score > 0) ? 0 : ($row_height + 2)) : ($row_height + 1)),
      'width'     => $width,
      'height'    => 2, #$score ? $row_height : 1,
      'absolutey' => 1
    }) );

    my $style = $self->get_featurestyle($f, $configuration);
    my $fdata = $self->get_featuredata($f, $configuration, $y_offset);

$fdata->{'height'} = 1;
#    my $symbol2 = Bio::EnsEMBL::Glyph::Symbol::box->new($fdata, $style->{'attrs'});
    my $symbol = Bio::EnsEMBL::Glyph::Symbol::line->new($fdata, $style->{'attrs'});
#    my $symbol = $self->get_symbol($style, $fdata, $y_offset);
#    $height = 0;
#    $symbol->{'style'}->{'height'} = $row_height;
#    $symbol->{'style'}->{'absolutey'} = 1;
#warn Data::Dumper::Dumper($symbol);

    $Composite->push($symbol->draw);
   my $hh = int(abs($y_offset - $pY));
    if (($START  == $pX) && ($hh > 1) ) { 
# warn ( join (' * ', 'S', $START, $score, $pY, $y_offset, $hh));
      $Composite->push( new Sanger::Graphics::Glyph::Line({
        'x'         => $START - 1,
      	'y'         =>  $y_offset > $pY ? $pY : $y_offset, #($score ? (($score > 0) ? 1 : ($row_height + 2)) : ($row_height + 1)),
        'width'     => 2,
        'height'    => $hh ,#20, #$score ? $row_height : 1,
'colour' => $symbol->{'style'}->{'colour'},
        'absolutey' => 1,
      }) );
    }
    $pX = $END;
    $pY = $y_offset;

    $self->push( $Composite );
  } # END loop over features

 return 1;
}   # END RENDER_plot

1;

