package Bio::EnsEMBL::GlyphSet;
use strict;

use Sanger::Graphics::Glyph::Bezier;
use Sanger::Graphics::Glyph::Circle;
use Sanger::Graphics::Glyph::Composite;
use Sanger::Graphics::Glyph::Diagnostic;
use Sanger::Graphics::Glyph::Ellipse;
use Sanger::Graphics::Glyph::Intron;
use Sanger::Graphics::Glyph::Line;
use Sanger::Graphics::Glyph::Poly;
use Sanger::Graphics::Glyph::Rect;
use Sanger::Graphics::Glyph::Space;
use Sanger::Graphics::Glyph::Sprite;
use Sanger::Graphics::Glyph::Text;

use Bio::EnsEMBL::Registry;

use GD;
use GD::Simple;
use GD::Text;
use CGI qw(escapeHTML escape);
use POSIX qw(floor ceil);

our $AUTOLOAD;

use base qw(Sanger::Graphics::GlyphSet);

our %cache;

#########
# constructor
#

sub _colour_background {
  return 1;
}
sub error_track_name {
  my $self = shift;
  return $self->my_config('caption');
}

sub render_normal {
  my $self = shift;
  my $rtn = $self->_init(@_);
  
  return $self->{'text_export'} && $self->can('render_text') ? $rtn : undef;
}

sub render {
  my $self = shift;
  
  my $method = 'render_' . $self->{'display'};
  
  $self->{'text_export'} = $self->{'config'}->get_parameter('text_export');
  
  my $text_export = $self->can($method) ? $self->$method(@_) : $self->render_normal;
  
  return $self->{'text_export'} ? $text_export : undef;
}

sub _render_text {
  my $self = shift;
  my ($feature, $feature_type, $extra, $defaults) = @_;
  
  return unless $feature;
  
  $extra = { 'headers' => [], 'values' => [] } unless keys %$extra;
  $defaults ||= {};
  
  my $format = $self->{'text_export'};
  my $header;
  
  if (!$self->{'export_header'}) {
    my @default_fields = qw( seqname source feature start end score strand frame );
    
    $header = join ("\t", @default_fields, @{$extra->{'headers'}}) . "\r\n" if ($format ne 'gff');
    
    $self->{'export_header'} = 1;
  }
  
  my $score   = $defaults->{'score'}  || ($feature->can('score') ? $feature->score : undef) || '.';
  my $frame   = $defaults->{'frame'}  || ($feature->can('frame') ? $feature->frame : undef) || '.';
  my $source  = $defaults->{'source'} || ($feature->can('source') ? $feature->source : ($self->my_config('db') eq 'vega' ? 'Vega' : 'Ensembl'));
  my $seqname = $defaults->{'seqname'};
  my $strand  = $defaults->{'strand'};
  my $start   = $defaults->{'start'};
  my $end     = $defaults->{'end'};
  
  $feature_type ||= $feature->can('primary_tag') ? $feature->primary_tag : '.';
  
  $seqname ||= 
    ($feature->can('seq_region_name') ? $feature->seq_region_name : undef) || 
    ($feature->can('entire_seq') && $feature->entire_seq ? $feature->entire_seq->name : $feature->can('seqname') ? $feature->seqname : undef) ||
    'SEQ';
  
  $strand ||= 
    ($feature->can('seq_region_strand') ? $feature->seq_region_strand : undef) || 
    ($feature->can('strand') ? $feature->strand : undef) ||
    '.';
  
  $start ||= ($feature->can('seq_region_start') ? $feature->seq_region_start : undef) || ($feature->can('start') ? $feature->start : undef);
  $end   ||= ($feature->can('seq_region_end')   ? $feature->seq_region_end : undef)   || ($feature->can('end')   ? $feature->end : undef);
  
  $feature_type =~ s/\s+/ /g;
  $source =~ s/\s+/ /g;
  $seqname =~ s/\s+/ /g;
  
  $source = ucfirst $source;
  
  $strand = '+' if $strand == 1;
  $strand = '-' if $strand == -1;
  
  my @results = ($seqname, $source, $feature_type, $start, $end, $score, $strand, $frame);
  
  if ($format eq 'gff') {
    my @ex;
    
    for (0..scalar @{$extra->{'headers'}}-1) {
      push @ex, "$extra->{'headers'}->[$_]=$extra->{'values'}->[$_]" if $extra->{'values'}->[$_];
    }
    
    push (@results, join ("; ", @ex));
  } else {
    push (@results, @{$extra->{'values'}});
  }
  
  return "$header" . join ("\t", @results) . "\r\n";
}

sub dbadaptor  {
  my $self = shift;
  return Bio::EnsEMBL::Registry->get_DBAdaptor( @_ );
}
sub species {
  my $self = shift;
  return $self->{'config'}{'species'} || $self->{'container'}{'web_species'};
}
sub timer_push {
  my($self,$capt,$dep,$flag) = @_;
  $dep  ||= 3;
  $flag ||= 'draw';
  $self->{'config'}{'species_defs'}->timer()->push($capt,$dep,$flag);
}

### Helper functions to wrap round Glyphs...

sub Bezier     { my $self = shift; return new Sanger::Graphics::Glyph::Bezier(     @_ ); }
sub Circle     { my $self = shift; return new Sanger::Graphics::Glyph::Circle(     @_ ); }
sub Composite  { my $self = shift; return new Sanger::Graphics::Glyph::Composite(  @_ ); }
sub Diagnostic { my $self = shift; return new Sanger::Graphics::Glyph::Diagnostic( @_ ); }
sub Ellipse    { my $self = shift; return new Sanger::Graphics::Glyph::Ellipse(    @_ ); }
sub Intron     { my $self = shift; return new Sanger::Graphics::Glyph::Intron(     @_ ); }
sub Line       { my $self = shift; return new Sanger::Graphics::Glyph::Line(       @_ ); }
sub Poly       { my $self = shift; return new Sanger::Graphics::Glyph::Poly(       @_ ); }
sub Rect       { my $self = shift; return new Sanger::Graphics::Glyph::Rect(       @_ ); }
sub Space      { my $self = shift; return new Sanger::Graphics::Glyph::Space(      @_ ); }
sub Sprite     { my $self = shift; return new Sanger::Graphics::Glyph::Sprite(     @_ ); }
sub Text       { my $self = shift; return new Sanger::Graphics::Glyph::Text(       @_ ); }

sub core {
  my $self = shift;
  my $k    = shift;
  return $self->{'config'}{_core}{'parameters'}{$k};
}
sub _url {
  my $self = shift;
  my $params  = shift || {};
  my $species = exists( $params->{'species'} ) ? $params->{'species'} : $self->{'container'}{'web_species'};
  my $type    = exists( $params->{'type'}    ) ? $params->{'type'}    : $ENV{'ENSEMBL_TYPE'};
  my $action  = exists( $params->{'action'}  ) ? $params->{'action'}  : $ENV{'ENSEMBL_ACTION'};
  my $function  = exists( $params->{'function'}) ? $params->{'function'}: $ENV{'ENSEMBL_FUNCTION'};
  $function = '' if $action ne $ENV{'ENSEMBL_ACTION'};

  my %pars = $params->{'__clear'} || !exists $self->{'config'}{_core}{'parameters'}
           ? () 
           : %{$self->{'config'}{_core}{'parameters'}}
           ;
  delete $params->{'__clear'} if exists $params->{'__clear'};
  delete $pars{'t'}  if $params->{'pt'};
  delete $pars{'pt'} if $params->{'t'}; 
  delete $pars{'t'}  if $params->{'g'} && $params->{'g'} ne $pars{'g'};

  foreach( keys %$params ) {
    $pars{$_} = $params->{$_} unless $_ =~ /^(species|type|action|function)$/;
  }
  my $URL = sprintf '/%s/%s/%s', $species, $type, $action.( $function ? "/$function" : "" );
  my $join = '?';
## Sort the keys so that the URL is the same for a given set of parameters...
  foreach ( sort keys %pars ) {
    if (defined $pars{$_}) {
      $URL .= sprintf '%s%s=%s', $join, escapeHTML($_), escapeHTML($pars{$_});
      $join = ';';
    }
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

sub init_label {
  my $self = shift;
  return $self->label(undef) if defined $self->{'config'}->{'_no_label'};
  
  my $text = $self->my_config('caption');
  
  return $self->label(undef) unless $text;
  
  my $name = $self->my_config('name');
  my $desc = $self->my_config('description');
  my $title = "$name; $desc" if $desc;
  
  my $ST = $self->{'config'}->species_defs->ENSEMBL_STYLE;
  my $font = $ST->{'GRAPHIC_FONT'};
  my $fsze = $ST->{'GRAPHIC_FONTSIZE'} * $ST->{'GRAPHIC_LABEL'};

  my @res = $self->get_text_width(0, $text, '', 'font' => $font, 'ptsize' => $fsze);

  $self->label($self->Text({
    'text'      => $text,
    'font'      => $font,
    'ptsize'    => $fsze,
    'title'     => $title,
    'colour'    => $self->{'label_colour'} || 'black',
    'absolutey' => 1,
    'height'    => $res[3]
  }));
}

sub species_defs {
### a
  my $self = shift;
  return $self->{'config'}->{'species_defs'};
}

sub get_textheight {
  my( $self, $name ) = @_;
  my( $fontname, $fontsize ) = $self->get_font_details( $name );
  my @res = $self->get_text_width( 0, 'X', '', 'font'=>$fontname, 'ptsize' => $fontsize );
  return $res[3];
}

sub get_text_simple {
### Simple function which calls the get_font_details and caches the result!!
  my( $self, $text, $text_size ) =@_;
  $text     ||='X';
  $text_size||='text';

  my( $f, $fs ) = $self->get_font_details( $text_size );
 
  my @T = $self->get_text_width( 0, $text, '', 'ptsize' => $fs, 'font' => $f );

  return {
    'original' => $text,
    'text'     => $T[0],
    'bit'      => $T[1],
    'width'    => $T[2],
    'height'   => $T[3],
    'font'     => $f,
    'fontsize' => $fs
  };
}

sub get_text_width {
  my( $self, $width, $text, $short_text, %parameters ) = @_;

  # Adjust the text for courier fonts
  if( length($text)==1 && $parameters{'font'} =~ /Cour/i ){ $text = 'X' }

  # Look in the cache for a previous entry 
  my $KEY = "$width--$text--$short_text--"
      . "$parameters{'font'}--$parameters{'ptsize'}";
  return @{$cache{$KEY}} if exists $cache{$KEY};

  # Get the GD::Text object for this font/size
  my $gd = $self->get_gd_simple($parameters{'font'},$parameters{'ptsize'})      || return(); # Ensure we have the text obj
#use Data::Dumper; warn Dumper( $gd->fontMetrics($parameters{'font'},$parameters{'ptsize'},$text) );
  # Use the text object to determine height/width of the given text;
  $width ||= 1e6; # Make initial width very big by default
  my($w,$h) = $gd->stringBounds($text); 
  my @res;
  if($w<$width) { 
    @res = ($text,      'full', $w,$h);
  } elsif($short_text) {
    ($w,$h) = $gd->stringBounds($text);
    if($w<$width) { 
      @res = ($short_text,'short',$w,$h);
    } else {
      @res = ('',         'none', 0, 0 );
    }
  } elsif( $parameters{'ellipsis'} ) {
    my $string = $text;
    while( $string ) {
      chop $string;
      ($w,$h) = $gd->stringBounds("$string...");
      if($w<$width) { 
        @res = ("$string...",'truncated',$w,$h);
        last;
      }
    }
  } else {
    @res = ('',         'none', 0, 0 );
  }
  $self->{'_cache_'}{$KEY} = \@res; # Update the cache
  $cache{$KEY} = \@res;
  return @res;
}

sub get_gd_simple {
### Returns the GD::Text object appropriate for the given fontname
### and fontsize. GD::Text objects are cached against fontname and fontsize.
  my $self   = shift;
  my $font   = shift || 'arial';
  my $ptsize = shift || 10;

  my $FONT_KEY = "${font}--${ptsize}"; 
  return $cache{"2:".$FONT_KEY} if exists( $cache{"2:".$FONT_KEY} );
  
  my $fontpath = $self->{'config'}->species_defs->ENSEMBL_STYLE->{'GRAPHIC_TTF_PATH'}."/$font.ttf";
  my $gd = GD::Simple->new( 400,400 );
  eval {
    if( -e $fontpath ) {
      $gd->font( $fontpath, $ptsize );
    } elsif( $font eq 'Tiny' ) {
      $gd->font( gdTinyFont );
    } elsif( $font eq 'MediumBold' ) {
      $gd->font( gdMediumBoldFont );
    } elsif( $font eq 'Large' ) {
      $gd->font( gdLargeFont );
    } elsif( $font eq 'Giant' ) {
      $gd->font( gdGiantFont );
    } else {
      $font = 'Small';
      $gd->font( gdSmallFont );
    }
  };
  warn $@ if $@;

  $cache{"2:".$FONT_KEY} = $gd; # Update font cache
  
  return $cache{"2:".$FONT_KEY};
}

sub get_gd_text {
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

sub commify {
### Puts commas into numbers over 1000
  my( $self, $val ) = @_;
  return $val if $val < 1000;
  $val = reverse $val;
  $val =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
  return reverse $val;
}

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
  my $data  = shift;
  if(!$class) {
    warn( "EnsEMBL::GlyphSet::failed at: ".gmtime()." in /$ENV{'ENSEMBL_SPECIES'}/$ENV{'ENSEMBL_SCRIPT'}" );
    warn( "EnsEMBL::GlyphSet::failed with a call of new on an undefined value" );
    return undef;
  }
  my $self = {
    'glyphs'     => [],
    'x'          => undef,
    'y'          => undef,
    'width'      => undef,
    'highlights' => $data->{'highlights'},
    'strand'     => $data->{'strand'},
    'minx'       => undef,
    'miny'       => undef,
    'maxx'       => undef,
    'maxy'       => undef,
    'label'      => undef,
    'bumped'     => undef,
    'bumpbutton' => undef,
    'label2'     => undef,
    'container'  => $data->{'container'},
    'config'     => $data->{'config'},
    'my_config'  => $data->{'my_config'},
    'display'    => $data->{'display'}||'off',
    'extras'     => $data->{'extra'}||{}
  };
  bless($self, $class);
  $self->init_label;

  return $self;
}

sub bumpbutton {
  my $self = shift;
  $self->{'bumpbutton'} = shift if @_;
  return $self->{'bumpbutton'};
}

sub label2 {
  my ($self, $val) = @_;
  $self->{'label2'} = $val if(defined $val);
  return $self->{'label2'};
}

sub get_parameter {
  my( $self, $key ) = @_;
  return $self->{'config'}->get_parameter( $key );
}

sub my_config {
  my( $self, $key ) = @_;
  return $self->{'my_config'}->get( $key );  ## Get value from track configuration...
}

## Stub - currently only implemented in vertical tracks
sub data { return undef; }

use Data::Dumper;
our $CC = 0;

sub my_colour {
  my( $self, $colour, $part, $default ) = @_;
  $self->{'colours'} ||= $self->my_config('colours')||{};
  if( $part eq 'text' || $part eq 'style' ) {
    if( $self->{'colours'} ) {
      return $self->{'colours'}->{$colour  }{$part}     if exists $self->{'colours'}->{$colour  }{$part    };
      return $self->{'colours'}->{'default'}{$part}     if exists $self->{'colours'}->{'default'}{$part    };
    }
    return defined( $default ) ? $default : 'Other (unknown)' if $part eq 'text';
    return '';
  }
  if( $self->{'colours'} ) {
    return $self->{'colours'}->{$colour  }{$part}     if exists $self->{'colours'}->{$colour  }{$part    };
    return $self->{'colours'}->{'default'}{$part}     if exists $self->{'colours'}->{'default'}{$part    };
    return $self->{'colours'}->{$colour  }{'default'} if exists $self->{'colours'}->{$colour  }{'default'};
    return $self->{'colours'}->{'default'}{'default'} if exists $self->{'colours'}->{'default'}{'default'};
  }
  return defined( $default ) ? $default : 'black';
}

sub _c {
  my( $self, $key ) = @_;
  my $T = $self->{'my_config'}->get( $key );
     $T = $self->{'config'}->get_parameter( $key ) unless defined $T;
  return $T;
}

sub _type {
  my $self = shift;
  return $self->{'my_config'}->key;
}

sub _pos {
  my $self = shift;
  return $self->{'my_config'}->left; ## Return left hand value... [ means legends will get rendered in order!! ]
}

sub set_my_config {
## Used to dynamically hack the configuration of this node... ## used by threshold calculation only at the moment...
## will sort this at some point not to need it - only used by clones [ although not in new code!! ]
  my( $self, $key, $val ) = @_;
  $self->{'my_config'}->set( $key, $val );
  return $val;
}

sub check {
  my( $self ) = @_;
  return $self->{'my_config'}{'_key'};
}

# Stuff copied out of scalebar.pm so that contig.pm can use it!
sub ID_URL {
  my ($self, $db, $id) = @_;
  
  return undef unless $self->species_defs;
  return undef if $db eq 'NULL';
  
  if (exists($self->species_defs->ENSEMBL_EXTERNAL_URLS->{$db})) {
    my $url = $self->species_defs->ENSEMBL_EXTERNAL_URLS->{$db};
    $url =~ s/###ID###/$id/;
    
    return $url;
  } else {
    return '';
  }
}

sub draw_cigar_feature {
  my ($self, $params) = @_;
  
  my ($composite, $f, $h) = map $params->{$_}, qw(composite feature height);
  
  my $ref = ref $f;
  
  if (!$ref) {
    warn sprintf 'DRAWINGCODE_CIGAR < %s > %s not a feature', $f, $self->label->text;
  } elsif ($ref eq 'SCALAR') {
    warn sprintf 'DRAWINGCODE_CIGAR << %s >> %s not a feature', $$f, $self->label->text;
  } elsif ($ref eq 'HASH') {
    warn sprintf 'DRAWINGCODE_CIGAR { %s } %s not a feature', join('; ', keys %$f), $self->label->text;
  } elsif ($ref eq 'ARRAY') { 
    warn sprintf 'DRAWINGCODE_CIGAR [ %s ] %s not a feature', join('; ', @$f), $self->label->text;
  }
  
  my $length  = $self->{'container'}->length;
  my $cigar;
  
  eval { $cigar = $f->cigar_string; };
  
  if ($@ || !$cigar) {
    my ($s, $e) = ($f->start, $f->end);
    $s = 1 if $s < 1;
    $e = $length if $e > $length; 
    
    $composite->push($self->Rect({
      x         => $s - 1,
      y         => 0,
      width     => $e - $s + 1,
      height    => $h,
      colour    => $params->{'feature_colour'},
      absolutey => 1
    }));
    
    return;
  }
  
  my $strand  = $self->strand;
  my $start   = $f->start;
  my $hstart  = $f->hstart;
  my $hend    = $f->hend;
  my $fstrand = $f->strand;
  my $hstrand = $f->hstrand;
  my @delete;
  
  my ($slice_start, $slice_end, $tag1, $tag2);
  
  if ($f->slice) {
    $slice_start = $f->slice->start;
    $slice_end   = $f->slice->end;
    $tag1        = join ':', $f->species, $f->slice->seq_region_name;
    $tag2        = join ':', $f->hspecies, $f->hseqname;
  } else {
    $slice_start = $f->seq_region_start;
    $slice_end   = $f->seq_region_end;
    $tag1        = $f->seqname;
  }
  
  # Parse the cigar string, splitting up into an array
  # like ('10M','2I','30M','I','M','20M','2D','2020M');
  # original string - "10M2I30MIM20M2D2020M"
  my @cigar = $f->cigar_string =~ /(\d*[MDImU])/g;
  @cigar = reverse @cigar if $fstrand == -1;
  
  foreach (@cigar) {
    # Split each of the {number}{Letter} entries into a pair of [ {number}, {letter} ] 
    # representing length and feature type ( 'M' -> 'Match/mismatch', 'I' -> Insert, 'D' -> Deletion )
    # If there is no number convert it to [ 1, {letter} ] as no-number implies a single base pair...
    my ($l, $type) = /^(\d+)([MDImU])/ ? ($1, $2) : (1, $_);
    
    # If it is a D (this is a deletion) and so we note it as a feature between the end
    # of the current and the start of the next feature (current start, current start - ORIENTATION)
    # otherwise it is an insertion or match/mismatch
    # we compute next start sa (current start, next start - ORIENTATION) 
    # next start is current start + (length of sub-feature) * ORIENTATION 
    my $s = $start;
    my $e = ($start += ($type eq 'D' ? 0 : $l)) - 1;
    
    my $s1 = $fstrand == 1 ? $slice_start + $s - 1 : $slice_end - $e + 1;
    my $e1 = $fstrand == 1 ? $slice_start + $e - 1 : $slice_end - $s + 1;
    
    my ($hs, $he);
    
    if ($fstrand == 1) {
      $hs = $hstart;
      $he = ($hstart += ($type eq 'I' ? 0 : $l)) - 1;
    } else {
      $he = $hend;
      $hs = ($hend -= ($type eq 'I' ? 0 : $l)) + 1;
    }
    
    # If a match/mismatch - draw box
    if ($type =~ /^[MmU]$/) {
      ($s, $e) = ($e, $s) if $s > $e; # Sort out flipped features
      
      next if $e < 1 || $s > $length; # Skip if all outside the box
      
      $s = 1       if $s < 1;         # Trim to area of box
      $e = $length if $e > $length;
      
      my $box = $self->Rect({
        x         => $s - 1,
        y         => 0,
        width     => $e - $s + 1,
        height    => $h,
        colour    => $params->{'feature_colour'},
        absolutey => 1
      });
      
      if ($params->{'link'}) {
        my $tag = $strand == 1 ? "$tag1:$s1:$e1#$tag2:$hs:$he" : "$tag2:$hs:$he#$tag1:$s1:$e1";
        my $x;
        
        if ($params->{'other_ori'} == $hstrand && $params->{'other_ori'} == 1) {
          $x = $strand == -1 ? 0 : 1; # Use the opposite value to normal to ensure alignments which are between different orientations by default do not display a cross-over join
        } else {
          $x = $strand == -1 ? 1 : 0;
        }
        
        $x ||= 1 if $fstrand == 1 && $hstrand * $params->{'other_ori'} == -1; # the feature has been flipped, so force x to the same value each time to achieve a cross-over join
        
        $self->join_tag($box, $tag, {
          x     => $x,
          y     => $strand == -1 ? 1 : 0,
          z     => $params->{'join_z'},
          col   => $params->{'join_col'},
          style => 'fill'
        });
        
        $self->join_tag($box, $tag, {
          x     => !$x,
          y     => $strand == -1 ? 1 : 0,
          z     => $params->{'join_z'},
          col   => $params->{'join_col'},
          style => 'fill'
        });
      }
      
      $composite->push($box);
    } elsif ($type eq 'D') { # If a deletion temp store it so that we can draw after all matches
      ($s, $e) = ($e, $s) if $s < $e;
      
      next if $e < 1 || $s > $length || $params->{'scalex'} < 1 ;  # Skip if all outside box
      
      push @delete, $e;
    }
  }

  # Draw deletion markers
  foreach (@delete) {
    $composite->push($self->Rect({
      x         => $_,
      y         => 0,
      width     => 0,
      height    => $h,
      colour    => $params->{'delete_colour'},
      absolutey => 1
    }));
  }
}

sub no_features {
  my $self = shift;
  $self->errorTrack(sprintf 'No %s in this region', $self->my_label) if $self->{'config'}->get_parameter('opt_empty_tracks') == 1;
}

sub errorTrack {
  my ($self, $message, $x, $y) = @_;
  
  my ($fontname, $fontsize) = $self->get_font_details('text');
  
  my $length = $self->{'config'}->image_width;
  my $style  = $self->{'config'}->species_defs->ENSEMBL_STYLE;
  my @res    = $self->get_text_width(0, $message, '', 'ptsize' => $fontsize, 'font' => $fontname);
  
  $self->push($self->Text({
    x             => $x || int(($length - $res[2]) / 2),
    y             => $y || 2,
    width         => $res[2],
    textwidth     => $res[2],
    height        => $res[3],
    halign        => 'center',
    font          => $fontname,
    ptsize        => $fontsize,
    colour        => 'red',
    text          => $message,
    absolutey     => 1,
    absolutex     => 1,
    absolutewidth => 1,
    pixperbp      => $self->{'config'}->{'transform'}->{'scalex'}
  }));

  return $res[3];
}

sub get_featurestyle {
  my ($self, $f, $configuration) = @_;
  
  my $style;
  
  if ($configuration->{'use_style'}) {
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
  my $start = $f->das_start < 1 ? 1 : $f->das_start;
  my $end   = $f->das_end   > $configuration->{'length'} ? $configuration->{'length'} : $f->das_end;
  my $row_height = $configuration->{'h'};

  # truncation flags
  my $trunc_start = $start ne $f->das_start ? 1 : 0;
  my $trunc_end   = $end ne $f->das_end     ? 1 : 0;
  my $orientation = $f->das_orientation;

  my $featuredata = {
    row_height    => $row_height,
    start         => $start,
    end           => $end ,
    pix_per_bp    => $self->{'pix_per_bp'},
    y_offset      => $y_offset,
    trunc_start   => $trunc_start,
    trunc_end     => $trunc_end,
    orientation   => $orientation
  };
  
  return $featuredata;
}

# Function will display DAS features with variable y-offset depending on SCORE attribute
# Similar to tiling array but allows for multiple types to be drawn side-by side 
# when 2 or more features are merged due to resolution the highest score will be used to determine the feature height


#==============================================================================================================
# Bumping code support!=
#==============================================================================================================

# _init_bump <- initialise the bumping code to be able to pack track...
# moved from separate Bump module so that it can be used in an OO way!!
# parameter passed is the maximum number of rows to bump... (optional)

# Initialize bumping - single parameter - max depth - if undefined it is "infinite"
sub _init_bump {
  my $self = shift;
  my $key  = shift || '_bump';
  
  $self->{$key} = {
    length => $self->{'config'}->image_width,
    rows   => @_ ? shift : 1e8,
    array  => []
  };
}

sub _max_bump_row {
  my ($self, $key) = @_;
  
  $key ||= '_bump';
  
  return scalar @{$self->{$key}{'array'}||[]};
}

# compute the row to bump the feature to.. parameters are start/end in drawing (pixel co-ordinates)
sub bump_row {
  my ($self, $start, $end, $truncate_if_outside, $key) = @_;
  
  $key ||= '_bump';

  ($end, $start) = ($start, $end) if $end < $start;

  $start = 1 if $start < 1;
  
  return -1 if $end > $self->{$key}{'length'} && $truncate_if_outside; # used to not display partial text labels
  
  $end = $self->{$key}{'length'} if $end > $self->{$key}{'length'};

  $start = floor($start);
  $end   = ceil($end);
  
  my $length  = $end - $start + 1;
  my $element = '0' x $self->{$key}{'length'};
  my $row     = 0;

  substr($element, $start, $length) = '1' x $length;
  
  while ($row < $self->{$key}{'rows'}) {
    if ($self->{$key}{'array'}[$row]) {
      if (($self->{$key}{'array'}[$row] & $element) == 0) {
        $self->{$key}{'array'}[$row] |= $element;
        last;
      } else {
        $row++;
        return 1e9 if $row > $self->{$key}{'rows'};
      }
    } else {
      $self->{$key}{'array'}[$row] |= $element;
      last;
    }
  }
  
  return $row;
}

#==============================================================================================================
# Return the das URL for the feature type....
#==============================================================================================================

sub de_camel { 
  my ($self, $string) = @_;
  $string =~ s/([a-z])([A-Z])/$1_$2/g;
  return lc $string;
}

sub human_readable {
  my ($self, $species) = @_;
  $species =~ s/_/ /g;
  return $species
}

sub readable_strand {
  my ($self, $strand) = @_;
  return $strand < 0 ? 'rev' : 'fwd';
}

sub cache {
  my $self = shift;
  my $key  = shift;
  $self->{'config'}{'_cache'}{$key} = shift if @_;
  return $self->{'config'}{'_cache'}{$key};
}

sub legend {
  my ($self, $key, $priority);
  $self->{'config'}{'legends'}{$key} ||= { priority => $priority, legend => [] };
}

sub scalex {
  my $self = shift;
  return $self->{'config'}->transform->{'scalex'};
}

sub image_width {
  my $self = shift;
  return $self->{'config'}->get_parameter('panel_width') || $self->{'config'}->image_width;
}

sub das_link {
  my $self = shift;
  
  my $slice    = $self->{'container'};
  my $das_type = $self->_das_type;
  my $species  = $self->species;
  
  return undef unless $das_type;
  
  return sprintf(
    '/das/%s.%s.%s/features?segment=%s:%d-%d',
    $slice->seq_region_name,
    $slice->species,
    $self->species_defs->get_config($species, 'ENSEMBL_GOLDEN_PATH'),
    join('-', $das_type,$self->my_config('db'), @{$self->my_config('logicnames')||[]}),
    $slice->start,
    $slice->end
  );
}

#==============================================================================================================
# Threshold update function to update parameters dependent on the width of the slice - this is a first stage
# approach of "context sensitive" track displays.
#==============================================================================================================

# Update parameters of the display based on the size of the
# slice... threshold_array contains a hash of values:
# 'threshold_array' => { 
#   slice_length_1 => { k=>v, .... } # hash 1
#   slice_length_2 => { k=>v, .... } # hash 2
# }
# If slice_length <= slice_length_1 - do nothing
# If slice_length_1 < slice_length <= slice_length_2 - update configuration values from - hash 1
# If slice_length_2 < slice_length ...               - update configuration values from - hash 2
# etc...
sub _threshold_update {
  my $self = shift;
  
  my $thresholds = $self->my_config('threshold_array');
  
  return unless $thresholds;
  
  my $container_length = $self->{'container'}->length;
  
  foreach my $th (sort { $a <=> $b } keys %$thresholds) {
    if ($container_length > $th * 1000) {
      $self->set_my_config($_, $thresholds->{$th}{$_}) for keys %{$thresholds->{$th}};
    }
  }
}

#==============================================================================================================
# Shared by a number of the transcript/gene drawing code - so putting here!
#==============================================================================================================

sub transcript_label {
  my ($self, $transcript, $gene) = @_;
  
  my $pattern = $self->my_config('label_key') || '[text_label]';
  
  return '' if $pattern eq '-';
  
  $pattern =~ s/\[text_label\]/$self->my_colour($self->transcript_key($transcript, $gene), 'text')/eg;
  $pattern =~ s/\[gene.(\w+)\]/$1 eq 'logic_name' || $1 eq 'display_label' ? $gene->analysis->$1 : $gene->$1/eg;
  $pattern =~ s/\[(\w+)\]/$1 eq 'logic_name' || $1 eq 'display_label' ? $transcript->analysis->$1 : $gene->$1/eg;
  
  return $pattern;
}

sub gene_label {
  my ($self, $gene) = @_;
  
  my $pattern = $self->my_config('label_key') || '[text_label]';
  
  return '' if $pattern eq '-';
  
  $pattern =~ s/\[text_label\]/$self->my_colour($self->gene_key($gene), 'text')/eg;
  $pattern =~ s/\[gene.(\w+)\]/$1 eq 'logic_name' || $1 eq 'display_label' ? $gene->analysis->$1 : $gene->$1/eg;
  $pattern =~ s/\[(\w+)\]/$1 eq 'logic_name' || $1 eq 'display_label' ? $gene->analysis->$1 : $gene->$1/eg;
  
  return $pattern;
}

sub transcript_key {
  my ($self, $transcript, $gene) = @_;
  
  my $pattern = $self->my_config('colour_key') || '[biotype]_[status]';
  
  $pattern =~ s/\[gene.(\w+)\]/$1 eq 'logic_name' ? $gene->analysis->$1 : $gene->$1/eg;
  $pattern =~ s/\[(\w+)\]/$1 eq 'logic_name' ? $transcript->analysis->$1 : $gene->$1/eg;
  
  return lc$pattern;
}

sub gene_key {
  my ($self, $gene) = @_;
  
  my $pattern = $self->my_config('colour_key') || '[biotype]_[status]';
  
  $pattern =~ s/\[gene.(\w+)\]/$1 eq 'logic_name' ? $gene->analysis->$1 : $gene->$1/eg;
  $pattern =~ s/\[(\w+)\]/$1 eq 'logic_name' ? $gene->analysis->$1 : $gene->$1/eg;
  
  return lc $pattern;
}

1;

