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

package EnsEMBL::Draw::GlyphSet;

### Base package for drawing a discreet section of a genomic image,
### such as a section of assembly, feature track, scalebar or track legend
### Uses GD and the EnsEMBL::Draw::Glyph codebase

use strict;

use GD;
use GD::Simple;
use URI::Escape qw(uri_escape);
use List::Util qw(max min);
use POSIX qw(floor ceil);
use JSON qw(to_json);

use EnsEMBL::Draw::Glyph::Circle;
use EnsEMBL::Draw::Glyph::Composite;
use EnsEMBL::Draw::Glyph::Intron;
use EnsEMBL::Draw::Glyph::Line;
use EnsEMBL::Draw::Glyph::Poly;
use EnsEMBL::Draw::Glyph::Barcode;
use EnsEMBL::Draw::Glyph::Triangle;
use EnsEMBL::Draw::Glyph::Rect;
use EnsEMBL::Draw::Glyph::Space;
use EnsEMBL::Draw::Glyph::Sprite;
use EnsEMBL::Draw::Glyph::Text;
use EnsEMBL::Draw::Glyph::Arc;

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::DnaDnaAlignFeature;

use EnsEMBL::Draw::Utils::Bump qw(text_bounds mr_bump do_bump);
use EnsEMBL::Web::Utils::RandomString qw(random_string);

use parent qw(EnsEMBL::Root);

our %cache;

sub new {
  my $class = shift;
  my $data  = shift;
  
  if (!$class) {
    warn 'EnsEMBL::GlyphSet::failed at: ' . gmtime() . " in /$ENV{'ENSEMBL_SPECIES'}/$ENV{'ENSEMBL_SCRIPT'}";
    warn 'EnsEMBL::GlyphSet::failed with a call of new on an undefined value';
    return undef;
  }
  
  my $self = {
    glyphs        => [],
    x             => undef,
    y             => undef,
    width         => undef,
    minx          => undef,
    miny          => undef,
    maxx          => undef,
    maxy          => undef,
    label         => undef,
    label2        => undef,
    bumped        => undef,
    error         => undef,
    features      => [],
    data          => [], ## New name for 'features'
    feature_cache => $data->{'feature_cache'}, ## Cached data for HAL alignments
    highlights    => $data->{'highlights'},
    strand        => $data->{'strand'},
    container     => $data->{'container'},
    config        => $data->{'config'},
    my_config     => $data->{'my_config'},
    display       => $data->{'display'} || 'off',
    legend        => $data->{'legend'}  || {},
    extras        => $data->{'extra'}   || {}
  };
  
  bless $self, $class;
  
  $self->{'features'} = $self->init;
  $self->init_label;

  return $self;
}

########## read-only getters
sub species            { return $_[0]->{'config'}{'species'} || $_[0]->{'container'}{'web_species'};                                                             }
sub species_defs       { return $_[0]->{'config'}->species_defs;                                                                                                 }
sub get_parameter      { return $_[0]->{'config'}->get_parameter($_[1]);                                                                                         }
sub core               { return $_[0]->{'config'}->hub->core_params->{$_[1]};                                                                                    }
sub scalex             { return $_[0]->{'config'}->transform_object->scalex;                                                                                     }
sub error_track_name   { return $_[0]->my_config('caption');                                                                                                     }
sub get_features       { return $_[0]->{'features'}; }

sub feature_cache  { 
  my ($self, $key, $data) = @_;
  return undef unless $key;
  if ($data) {
    $self->{'feature_cache'}{$key} = $data;
  }
  return $self->{'feature_cache'}{$key}; 
}

sub my_label           { return $_[0]->my_config('caption');                                                                                                     }
sub my_label_caption   { return $_[0]->my_config('labelcaption');                                                                                                }
sub depth              { return $_[0]->my_config('depth');                                                                                                       }
sub my_config          { return $_[0]->{'my_config'}->get($_[1]);                                                                                                }
sub type               { return $_[0]->{'my_config'}{'id'};                                                                                                      }
sub _pos               { return $_[0]->{'config'}{'_pos'}++;                                                                                                     }
sub _colour_background { return 1;                                                                                                                               }
sub colour_key         { return 'default';                                                                                                                       }
sub feature_label      { return '';                                                                                                                              }
sub title              { return '';                                                                                                                              }
sub href               { return undef;                                                                                                                           }
sub tag                { return ();                                                                                                                              }
sub label_overlay      { return undef;                                                                                                                           }
sub get_colour         { my $self = shift; return $self->my_colour($self->colour_key(shift), @_);                                                                }
sub _url               { my $self = shift; return $self->{'config'}->hub->url('ZMenu', { %{$_[0]}, config => $self->{'config'}{'type'}, track => $self->type }); }
sub _quick_url         {
  my ($self,$params) = @_;

  $params = { %$params, config => $self->{'config'}{'type'},
              track => $self->type };
  my $out = '#:@:';
  foreach my $k (sort keys %$params) {
    my $v = $params->{$k}||'';
    $out .= sprintf("%d-%s-%d-%s-",length($k),$k,length($v),$v);
  }
  return $out;
}

sub image_width        { return $_[0]->{'config'}->get_parameter('panel_width') || $_[0]->{'config'}->image_width;                                               }
sub dbadaptor          { shift; return Bio::EnsEMBL::Registry->get_DBAdaptor(@_);                                                                                }
sub x {
  my ($self) = @_;
  return $self->{'x'};
}

sub y {
  my ($self) = @_;
  return $self->{'y'};
}

sub highlights {
  my ($self) = @_;
  return defined $self->{'highlights'} ? @{$self->{'highlights'}} : ();
}

########## read-write get/setters...

sub error              { my $self = shift; $self->{'error'} = @_ if @_; return $self->{'error'};                                                                 }
sub minx {
  my ($self, $minx) = @_;
  $self->{'minx'} = $minx if(defined $minx);
  return $self->{'minx'};
}

sub miny {
  my ($self, $miny) = @_;
  $self->{'miny'} = $miny if(defined $miny);
  return $self->{'miny'};
}

sub maxx {
  my ($self, $maxx) = @_;
  $self->{'maxx'} = $maxx if(defined $maxx);
  return $self->{'maxx'};
}

sub maxy {
  my ($self, $maxy) = @_;
  $self->{'maxy'} = $maxy if(defined $maxy);
  return $self->{'maxy'};
};

sub strand {
  my ($self, $strand) = @_;
  $self->{'strand'} = $strand if(defined $strand);
  return $self->{'strand'};
}

############# GLYPHS ######################

sub glyphs {
### return our list of glyphs
  my ($self) = @_;
  return @{$self->{'glyphs'}};
}

sub push {
### push either a Glyph or a GlyphSet on to our list
  my $self = CORE::shift;
  my ($gx, $gx1, $gy, $gy1);

  foreach my $Glyph (@_) {
    next unless $Glyph;
    CORE::push @{$self->{'glyphs'}}, $Glyph;

    $gx  =     $Glyph->x() || 0;
    $gx1 = $gx + ($Glyph->width() || 0);
    $gy  =     $Glyph->y() || 0;
    $gy1 = $gy + ($Glyph->height() || 0);

  ######### track max and min dimensions
    $self->minx($gx)  unless defined $self->minx && $self->minx < $gx;
    $self->maxx($gx1) unless defined $self->maxx && $self->maxx > $gx1;
    $self->miny($gy)  unless defined $self->miny && $self->miny < $gy;
    $self->maxy($gy1) unless defined $self->maxy && $self->maxy > $gy1;
  }
}

sub unshift {
### unshift a Glyph or GlyphSet onto our list
  my $self = CORE::shift;

  my ($gx, $gx1, $gy, $gy1);

  foreach my $Glyph (reverse @_) {
    CORE::unshift @{$self->{'glyphs'}}, $Glyph;

        $gx  =     $Glyph->x();
         $gx1 = $gx + $Glyph->width();
    $gy  =     $Glyph->y();
         $gy1 = $gy + $Glyph->height();

    $self->minx($gx)  unless defined $self->minx && $self->minx < $gx;
    $self->maxx($gx1) unless defined $self->maxx && $self->maxx > $gx1;
    $self->miny($gy)  unless defined $self->miny && $self->miny < $gy;
    $self->maxy($gy1) unless defined $self->maxy && $self->maxy > $gy1;
  }
}

sub pop {
### pop a Glyph or GlyphSet off of our list
  my ($self) = @_;
  return CORE::pop @{$self->{'glyphs'}};
}

sub shift {
### shift a Glyph or GlyphSet off of our list
  my ($self) = @_;
  return CORE::shift @{$self->{'glyphs'}};
}


### Helper functions to wrap round Glyphs
sub Circle     { my $self = shift; return EnsEMBL::Draw::Glyph::Circle->new(@_);     }
sub Composite  { my $self = shift; return EnsEMBL::Draw::Glyph::Composite->new(@_);  }
sub Intron     { my $self = shift; return EnsEMBL::Draw::Glyph::Intron->new(@_);     }
sub Line       { my $self = shift; return EnsEMBL::Draw::Glyph::Line->new(@_);       }
sub Poly       { my $self = shift; return EnsEMBL::Draw::Glyph::Poly->new(@_);       }
sub Barcode    { my $self = shift; return EnsEMBL::Draw::Glyph::Barcode->new(@_);       }
sub Rect       { my $self = shift; return EnsEMBL::Draw::Glyph::Rect->new(@_);       }
sub Space      { my $self = shift; return EnsEMBL::Draw::Glyph::Space->new(@_);      }
sub Sprite     { my $self = shift; return EnsEMBL::Draw::Glyph::Sprite->new(@_);     }
sub Text       { my $self = shift; return EnsEMBL::Draw::Glyph::Text->new(@_);       }
sub Triangle   { my $self = shift; return EnsEMBL::Draw::Glyph::Triangle->new(@_);   }
sub Arc        { my $self = shift; return EnsEMBL::Draw::Glyph::Arc->new(@_);   }

sub _init {
### _init creates masses of Glyphs from a data source.
### It should executes bumping and globbing on the fly and also
### keep track of x,y,width,height as it goes.
  my ($self) = @_;
  print STDERR qq($self unimplemented\n);
}

sub init { return []; } ## New method used by refactored glyphsets

sub features {
  my $self = shift;
  return $self->get_data(@_);
}

sub bumped {
  my ($self, $val) = @_;
  $self->{'bumped'} = $val if(defined $val);
  return $self->{'bumped'};
}

## additional derived functions

sub height {
  my ($self) = @_;
  ## New drawing code calculates its height differently
  my $h = $self->{'my_config'}->get('total_height');
  my $old_h = int(abs($self->{'maxy'}-$self->{'miny'}) + 0.5);
  return $h > $old_h ? $h : $old_h;
}

sub width {
  my ($self) = @_;
  return abs($self->{'maxx'}-$self->{'minx'});
}

sub length {
  my ($self) = @_;
  return scalar @{$self->{'glyphs'}};
}

sub transform {
  my ($self) = @_;
  my $transform_obj = $self->{'config'}->transform_object;
  foreach( @{$self->{'glyphs'}} ) {
    $_->transform($transform_obj);
  }
}

sub track_style_config {
### Bring together the various config options in a format
### that can be used by the new Style modules
  my $self = shift;
  my ($fontname, $fontsize) = $self->get_font_details('outertext');
  return {
          'image_config' => $self->{'config'},
          'track_config' => $self->{'my_config'},
          'pix_per_bp'   => $self->scalex,
          'font_name'    => $fontname,
          'font_size'    => $fontsize,
          };
}

sub data_for_strand {
### Munge the data so we only have what's needed for drawing
### on this strand, ready to pass into E::D::Style modules
  my ($self, $all_data) = @_;
  my $strand = $self->strand;
  my $data   = [];
  foreach my $subtrack (@$all_data) {
    push @$data, {
                  'metadata'  => $subtrack->{'metadata'} || {},
                  'features'  => $subtrack->{'features'}{$strand} || [],
                  };
  }

  return $data;
}

sub features_as_json {
### Fetch normal feature hash, then convert to JSON  
  my $self = shift;
  if ($self->can_json) {
    my $features = $self->features;
    if ($features) {
      if (ref $features eq 'ARRAY' || ref $features eq 'HASH') {
        return to_json($features);
      }
      else {
        warn "!!! FEATURES NOT JSON-COMPATIBLE";
      }
    }
  }
  else {
    warn "!!! NO JSON SUPPORT IN GLYPHSET $self";
  }
}

sub can_json {
### Temporary method - needed until all drawing code is moved to new structure
### Should be set to 1 in modules that support it
  return 0;
}

sub bg_href {
  my ($self, $height) = @_;
  return {} unless $self->{'my_config'}->get('link_on_bgd') && $self->can('bg_link');

  ## Background link - needed for zmenus
  ## Needs to be first to capture clicks
  ## Useful to keep zmenus working on blank regions
  ## only useful in nobump or strandbump modes
  my %off   = ( 0 => 0 );
  $height ||= $self->{'my_config'}->get('height');

  if ($self->my_config('strandbump')) {
    $off{0}       = -1;
    $off{$height} = 1;
  }

  my $bg_href = {};
  foreach my $y (keys %off) {
    $bg_href->{$y} = $self->bg_link($off{$y});
  }

  return $bg_href;
}


############### GENERIC RENDERING ####################

sub render {
  my $self   = shift;
  my $method = "render_$self->{'display'}";
  
  $self->{'text_export'} = $self->{'config'}->get_parameter('text_export');
  
  my $text_export = $self->can($method) ? $self->$method(@_) : $self->render_normal;
  
  return $self->{'text_export'} ? $text_export : undef;
}

sub render_normal {
  my $self = shift;
  my $rtn  = $self->_init(@_);
  return $self->{'text_export'} && $self->can('render_text') ? $rtn : undef;
}

sub _render_text {
  my $self = shift;
  my ($feature, $feature_type, $extra, $defaults) = @_;
  
  return unless $feature;
  
  $extra      = { headers => [], values => [] } unless keys %$extra;
  $defaults ||= {};
  
  my $format = $self->{'text_export'};
  my $header;
  
  if (!$self->{'export_header'}) {
    my @default_fields = qw(seqname source feature start end score strand frame);
       $header         = join ("\t", @default_fields, @{$extra->{'headers'}}) . "\r\n" if $format ne 'gff';
       
    $self->{'export_header'} = 1;
  }
  
  my $score   = $defaults->{'score'}  || ($feature->can('score') ? $feature->score : undef) || '.';
  my $frame   = $defaults->{'frame'}  || ($feature->can('frame') ? $feature->frame : undef) || '.';
  my $source  = $defaults->{'source'} || ($feature->can('source') ? $feature->source : $self->my_config('db') eq 'vega' ? 'Vega' : 'Ensembl');
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
    ($feature->can('strand')            ? $feature->strand            : undef) ||
    '.';
  
  $start ||= ($feature->can('seq_region_start') ? $feature->seq_region_start : undef) || ($feature->can('start') ? $feature->start : undef);
  $end   ||= ($feature->can('seq_region_end')   ? $feature->seq_region_end   : undef) || ($feature->can('end')   ? $feature->end   : undef);
  
  $feature_type =~ s/\s+/ /g;
  $source       =~ s/\s+/ /g;
  $seqname      =~ s/\s+/ /g;
  $source       = ucfirst $source;
  $strand       = '+' if $strand == 1;
  $strand       = '-' if $strand == -1;
  
  my @results = ($seqname, $source, $feature_type, $start, $end, $score, $strand, $frame);
  
  if ($format eq 'gff') {
    my @ex;
    
    for (0..scalar @{$extra->{'headers'}}-1) {
      CORE::push @ex, "$extra->{'headers'}->[$_]=$extra->{'values'}->[$_]" if $extra->{'values'}->[$_];
    }
    
    CORE::push @results, join '; ', @ex;
  } else {
    CORE::push @results, @{$extra->{'values'}};
  }
  
  return $header . join ("\t", @results) . "\r\n";
}

################# SUBTITLES #########################

sub subtitle_text {
  my ($self) = @_;

  return $self->my_config('subtitle') || $self->my_config('caption');
}

sub use_subtitles {
  my ($self) = @_;

  return
    $self->{'config'}->get_option('opt_subtitles') &&
    $self->supports_subtitles && $self->subtitle_text;
}

sub subtitle_height {
  my ($self) = @_;

  return ($self->use_subtitles?15:0);
}

sub subtitle_colour {
  my ($self) = @_;

  return 'slategray';
}

sub supports_subtitles {
  return 0;
}

################### GANGS #######################

sub gang_prepare {
}

sub gang {
  my ($self,$val) = @_;

  $self->{'_gang'} = $val if @_>1;
  return $self->{'_gang'};
}

################### LABELS ##########################

sub label {
  my ($self, $val) = @_;
  $self->{'label'} = $val if(defined $val);
  return $self->{'label'};
}

sub label_img {
  my ($self, $val) = @_;
  $self->{'label_img'} = $val if(defined $val);
  return $self->{'label_img'};
}

sub _label_glyphs {
  my ($self) = @_;

  my $label = $self->label;
  return [] unless $label;
  my $glyphs = [$label];
  if($label->can('glyphs')) {
    $glyphs = [ $self->{'label'}->glyphs ];
  }
  return $glyphs;
}

sub label_text {
  my ($self) = @_;

  return join(' ',map { $_->{'text'} } @{$self->_label_glyphs});
}


sub init_label {
  my $self = shift;
  
  return $self->label(undef) if defined $self->{'config'}->{'_no_label'};
  
  my $text = $self->my_config('caption'); 

  my $img = $self->my_config('caption_img');
  $img = undef if $SiteDefs::ENSEMBL_NO_LEGEND_IMAGES;
  if($img and $img =~ s/^r:// and $self->{'strand'} ==  1) { $img = undef; }
  if($img and $img =~ s/^f:// and $self->{'strand'} == -1) { $img = undef; }

  return $self->label(undef) unless $text;
  
  my $config    = $self->{'config'};
  my $hub       = $config->hub;
  my $name      = $self->my_config('name');
  my $desc      = $self->my_config('description');
  my $style     = $config->species_defs->ENSEMBL_STYLE;
  my $font      = $style->{'GRAPHIC_FONT'};
  my $fsze      = $style->{'GRAPHIC_FONTSIZE'} * $style->{'GRAPHIC_LABEL'};
  my @res       = $self->get_text_width(0, $text, '', font => $font, ptsize => $fsze);
  my $track     = $self->type;
  my $node      = $config->get_node($track);
  my $component = $config->get_parameter('component');
  my $hover     = ($text =~m/Legend/)? 0 : $component && !$hub->param('export') && $node->get('menu') ne 'no' && $track ne 'scalebar';
  my $class     = random_string(8);
  my $strand_map= { '1' => 'f', '-1' => 'r' };
  my $strand    = $node->get('drawing_strand') && $self->strand ? $strand_map->{$self->strand} : '';
  my $highlight_track_uniq_id = $strand ? "$track." . $strand : $track;
  my $matrix_cell = $node->get('matrix_cell') ? 1 : 0;

  $self->{'track_highlight_class'} = $highlight_track_uniq_id;

  ## Store this where the glyphset can find it later...
  $self->{'hover_label_class'} = $class;

  if ($hover) {
    my $fav       = $config->is_track_favourite($track);
    my $hl        = $config->is_track_highlighted($track);
    my @renderers = grep !/default/i, @{$node->get('renderers') || []};
    my $subset    = $node->get('subset');
    my @r;
    
    my $url = $hub->url('Config', {
      species  => $config->species,
      action   => $component,
      function => undef,
      submit   => 1
    });
    
    if (scalar @renderers > 4) {
      while (my ($val, $text) = splice @renderers, 0, 2) {
        CORE::push @r, { url => "$url;$track=$val", val => $val, text => $text, current => $val eq $self->{'display'} };
      }
    }

    ## GRAPH Y-AXIS STUFF    
    my $scaleable = $self->{'my_config'}->get('scaleable') ? $url : ''; 
    my ($y_min, $y_max);
    if (defined($self->{'my_config'}->get('y_min'))) {
      $y_min = $self->{'my_config'}->get('y_min');;
    }
    elsif (defined($self->{'my_config'}{'data'}{'y_min'})) {
      $y_min = $self->{'my_config'}{'data'}{'y_min'};
    }
    if (defined($self->{'my_config'}->get('y_max'))) {
      $y_max = $self->{'my_config'}->get('y_max');
    }
    elsif (defined($self->{'my_config'}{'data'}{'y_max'})) {
      $y_max = $self->{'my_config'}{'data'}{'y_max'};
    }

    $config->{'hover_labels'}->{$class} = {
      header          => $name,
      desc            => $desc,
      class           => "$class $track $strand",
      track_highlight => [ $highlight_track_uniq_id, $hl, "$url;updated=0;$track=highlight_" ],
      component       => lc($component . ($config->get_parameter('multi_species') && $config->species ne $hub->species ? '_' . $config->species : '')),
      renderers       => \@r,
      track           => $track,
      scaleable       => $scaleable,
      y_min           => $y_min, 
      y_max           => $y_max, 
      fav             => [ $fav, "$url;updated=0;$track=favourite_" ],
      off             => "$url;$track=off",
      conf_url        => $self->species eq $hub->species ? $hub->url($hub->multi_params) . ";$config->{'type'}=$track=$self->{'display'}" : '',
      subset          => $subset ? [ $subset, $hub->url('Config', { species => $config->species, action => $component, function => undef, __clear => 1 }), lc "modal_config_$component" ] : '',
      matrix_cell     => $matrix_cell,
    };
  }
 
  my $ch = $self->my_config('caption_height') || 0;
  my $tooltip = sprintf '%s (%s)',
                $config->species_defs->get_config($config->species, 'SPECIES_DISPLAY_NAME'),
                $config->species_defs->get_config($config->species, 'SPECIES_SCIENTIFIC_NAME');

  $self->label($self->Text({
    text      => $text,
    font      => $font,
    ptsize    => $fsze,
    colour    => $self->{'label_colour'} || 'black',
    absolutey => 1,
    height    => $ch || $res[3],
    class     => "label $class",
    alt       => $tooltip,
    hover     => $hover,
  }));

  if($img) {
    $img =~ s/^([\d@-]+)://; my $size = $1 || 16;
    my $offset = 0;
    $offset = $1 if $size =~ s/@(-?\d+)$//;

    $self->label_img($self->Sprite({
        z             => 1000,
        x             => 0,
        y             => $offset,
        sprite        => $img,
        spritelib     => 'species',
        width         => $size,
        height         => $size,
        absolutex     => 1,
        absolutey     => 1,
        absolutewidth => 1,
        pixperbp      => 1,
        href          => '#',
        class         => 'tooltip',
        alt           => $tooltip,
    }));
  }
}

sub _split_label {
# Text wrapping is a job for the human eye. We do the best we can:
# wrap on word boundaries but don't have <6 trailing characters.
  my ($self,$text,$width,$font,$ptsize,$chop) = @_;

  for (1..$chop) {
    $text =~ s/.\t</\t</;
    $text =~ s/\t>./\t>/;
  }
  $text =~ s/\t[<>]//;
  my $max_rows = $self->max_label_rows;
  my @words = split(/(?<=[ \-\._])/,$text);
  while(@words > 1 and length($words[-1]) < 6) {
    my $tail = pop @words;
    $words[-1] .= $tail;
  }
  my @split;
  my $line_so_far = '';
  foreach my $word (@words) {
    my $candidate_line = $line_so_far.$word;
    my $replacement_line = $candidate_line;
    $candidate_line =~ s/^ +//;
    $candidate_line =~ s/ +$//;
    my @res = $self->get_text_width(undef, $candidate_line, '', font => $font, ptsize => $ptsize);
    if(!@split or $res[2] > $width) { # CR
      if(@split == $max_rows) { # No room!
        my @res = $self->get_text_width($width, $candidate_line, '', ellipsis => 1, font => $font, ptsize => $ptsize);
        $split[-1][0] = $res[0];
        $split[-1][1] = $res[2];
        return (\@split,$text,1);
        last;
      }
      my @res = $self->get_text_width($width, $word, '', ellipsis => 1, font => $font, ptsize => $ptsize);
      $line_so_far = $res[0];
      CORE::push @split,[$line_so_far,$res[2]];
    } else {
      $line_so_far = $replacement_line;
      $split[-1][0] = $line_so_far;
      $split[-1][1] = $res[2];
    }
  }
  return (\@split,$text,0);
}

sub wrap {
  my ($self,$text,$width,$font,$ptsize) = @_;

  my ($split,$x,$trunc) = $self->_split_label($text,$width,$font,$ptsize);
  return [ map { $_->[0] } @$split ] unless $trunc;
  # Split naively
  # XXX probably slow: should do binary search
  my @out = ('');
  foreach my $t (split(//,$text)) {
    my @sizes = $self->get_text_width(0,$out[-1].$t,'',font => $font, ptsize => $ptsize);
    if($sizes[2]>$width) {
      push @out,'';
    }
    $out[-1].=$t;
  }
  return \@out;
}

sub recast_label {
  # XXX we should see which of these args are used and also pass as hash
  my ($self,$width,$rows,$text,$font,$ptsize,$colour) = @_;

  my $caption = $self->my_label_caption;
  $text = $caption if $caption;

  my $n = 0;
  my ($ov,$text_out);
  ($rows,$text_out,$ov) = $self->_split_label($text,$width,$font,$ptsize,0);
  if($ov and $text =~ /\t[<>]/) {
    $text.="\t<" unless $text =~ /\t[<>]/;
    $text =~ s/\t>./...\t>/;
    $text =~ s/.\t</\t<.../;
    my $ov = 1;
    my $text_out;
    my $known_good = length $text;
    my $known_bad = 0;
    my $good_rows;
    foreach my $step ((5,2,1)) {
      my $n = $known_bad + $step;
      while($n<$known_good) {
        ($rows,$text_out,$ov) = $self->_split_label($text,$width,$font,$ptsize,$n);
        if($ov) { $known_bad = $n; }
        else    { $known_good = $n; $good_rows = $rows; }
        $n += $step;
      }
    }
    $rows = $good_rows if defined $good_rows;
  }
  ## Save this so we can use in new drawing code
  $self->{'my_config'}->set('track_label_rows', scalar @$rows);

  my $max_width = max(map { $_->[1] } @$rows);

  my $composite = $self->Composite({
    halign => 'left',
    absolutex => 1,
    absolutewidth => 1,
    absolutey => 1,
    width => $max_width,
    x => 0,
    y => 0,
    track     => $self->{'track_highlight_class'} || $self->type,
    class     => $self->label->{'class'},
    alt       => $self->label->{'alt'},
    hover     => $self->label->{'hover'},
  });

  my $make_level = $self->use_subtitles ? 1 : 0; ## Adjust position if track has an in-image label
  my $y = $make_level ? 5 : 0;
  my $h = $self->my_config('caption_height') || $self->label->{'height'};
  my $count = 0;

  foreach my $row_data (@$rows) {
    my ($row_text,$row_width) = @$row_data;
    next unless $row_text;
    my $pad = 0;
    # Add some extra delimiting margin for the next row (if any)
    if ($make_level) {
      if ($count > 0) {
        $pad = 4;
      }
    }
    else {
      $y = 1 if !$count and @$rows > 1;
    }
    my $row = $self->Text({
      font => $font,
      ptsize => $ptsize,
      text => $row_text,
      height => $h + $pad,
      colour    => $colour,
      y => $y,
      width => $max_width,
      halign => 'left',
    });
    $composite->push($row);
    $y += $h + $pad; 
    $count++;
  }
  $self->label($composite);
}

sub get_text_simple {
### Simple function which calls the get_font_details and caches the result!!
  my ($self, $text, $text_size) = @_;
  $text      ||= 'X';
  $text_size ||= 'text';
  my ($f, $fs) = $self->get_font_details($text_size);
  my @t        = $self->get_text_width(0, $text, '', ptsize => $fs, font => $f);

  return {
    original => $text,
    text     => $t[0],
    bit      => $t[1],
    width    => $t[2],
    height   => $t[3],
    font     => $f,
    fontsize => $fs
  };
}

sub get_font_details {
  my ($self, $type, $hash) = @_;
  my $style  = $self->{'config'}->species_defs->ENSEMBL_STYLE;
  my $font   = $type =~ /fixed/i ? $style->{'GRAPHIC_FONT_FIXED'} : $style->{'GRAPHIC_FONT'};
  my $ptsize = $style->{'GRAPHIC_FONTSIZE'} * ($style->{'GRAPHIC_' . uc $type} || 1);
  
  return $hash ? (font => $font, ptsize => $ptsize) : ($font, $ptsize);
}

sub get_text_width {
  my ($self, $width, $text, $short_text, %parameters) = @_;
     $text = 'X' if length $text == 1 && $parameters{'font'} =~ /Cour/i;               # Adjust the text for courier fonts
  my $key  = "$width--$text--$short_text--$parameters{'font'}--$parameters{'ptsize'}"; # Look in the cache for a previous entry 
  #warn ">>> KEY $key";
  
  return @{$cache{$key}} if exists $cache{$key};

  my $gd = $self->get_gd($parameters{'font'}, $parameters{'ptsize'});
  
  return unless $gd;
  
  # Use the text object to determine height/width of the given text;
  $width ||= 1e6; # Make initial width very big by default
  
  my ($w, $h) = $gd->stringBounds($text); 
  my @res;
  
  if ($w < $width) { 
    @res = ($text, 'full', $w, $h);
  } elsif ($short_text) {
    ($w, $h) = $gd->stringBounds($text);
    @res = $w < $width ? ($short_text, 'short', $w, $h) : ('', 'none', 0, 0);
  } elsif ($parameters{'ellipsis'}) {
    my $string = $text;
    
    while ($string) {
      chop $string;
      
      ($w, $h) = $gd->stringBounds("$string...");
      
      if ($w < $width) { 
        @res = ("$string...", 'truncated', $w, $h);
        last;
      }
    }
  } else {
    @res = ('', 'none', 0, 0);
  }
  
  $self->{'_cache_'}{$key} = $cache{$key} = \@res; # Update the cache
  
  return @res;
}

sub get_gd {
  ### Returns the GD::Simple object appropriate for the given fontname
  ### and fontsize. GD::Simple objects are cached against fontname and fontsize.
  
  my $self     = shift;
  my $font     = shift || 'Arial';
  my $ptsize   = shift || 10;
  my $font_key = "${font}--${ptsize}"; 
  
  return GD::Simple->newFromPngData($cache{$font_key}) if exists $cache{$font_key};

  my $fontpath = $self->{'config'}->species_defs->get_font_path."$font.ttf";
  my $gd       = GD::Simple->new(400, 400);
  
  eval {
    if (-e $fontpath) {
      $gd->font($fontpath, $ptsize);
    } elsif ($font eq 'Tiny') {
      $gd->font(gdTinyFont);
    } elsif ($font eq 'MediumBold') {
      $gd->font(gdMediumBoldFont);
    } elsif ($font eq 'Large') {
      $gd->font(gdLargeFont);
    } elsif ($font eq 'Giant') {
      $gd->font(gdGiantFont);
    } else {
      $font = 'Small';
      $gd->font(gdSmallFont);
    }
  };
  
  warn $@ if $@;

  $cache{$font_key} = $gd->png; # Update font cache using PNG format
  return $gd;
}

sub bp_to_nearest_unit {
  my ($self, $bp, $dp) = @_;

  $dp = 1 unless defined $dp;

  my @units = qw( bp kb Mb Gb Tb );
  my $power = int((length(abs $bp) - 1) / 3);

  my $unit = $units[$power];

  my $value = int($bp / (10 ** ($power * 3)));

  $value = sprintf "%.${dp}f", $bp / (10 ** ($power * 3)) if $unit ne 'bp';

  return "$value $unit";
}

sub commify {
  ### Puts commas into numbers over 1000
  my ($self, $val) = @_;
  return $val if $val < 1000;
  $val = reverse $val;
  $val =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
  return reverse $val;
}

sub slice2sr {
  my ($self, $s, $e) = @_;

  return $self->{'container'}->strand < 0 ?
    ($self->{'container'}->end   - $e + 1, $self->{'container'}->end   - $s + 1) : 
    ($self->{'container'}->start + $s - 1, $self->{'container'}->start + $e - 1);
}

sub sr2slice {
  my ($self, $s, $e) = @_;

  return $self->{'container'}->strand < 0 ? 
    ( $self->{'container'}->end   - $e + 1,  $self->{'container'}->end   - $s + 1) :
    (-$self->{'container'}->start + $s + 1, -$self->{'container'}->start + $e + 1);
}

sub label2 {
  my ($self, $val) = @_;
  $self->{'label2'} = $val if defined $val;
  return $self->{'label2'};
}

sub cache {
  my $self = shift;
  my $key  = shift;
  $self->{'config'}{'_cache'}{$key} = shift if @_;
  return $self->{'config'}{'_cache'}{$key};
}

sub my_colour {
  my ($self, $colour, $part, $default) = @_;
  
  $self->{'colours'} ||= $self->my_config('colours') || {};
  
  if ($part eq 'text' || $part eq 'style') {
    if ($self->{'colours'}) {
      return $self->{'colours'}->{$colour  }{$part} if exists $self->{'colours'}->{$colour  }{$part};
      return $self->{'colours'}->{'default'}{$part} if exists $self->{'colours'}->{'default'}{$part};
    }
    
    return defined $default ? $default : 'Other (unknown)' if $part eq 'text';
    return '';
  }
  
  if ($self->{'colours'}) {
    return $self->{'colours'}->{$colour  }{$part}     if exists $self->{'colours'}->{$colour  }{$part    };
    return $self->{'colours'}->{'default'}{$part}     if exists $self->{'colours'}->{'default'}{$part    };
    return $self->{'colours'}->{$colour  }{'default'} if exists $self->{'colours'}->{$colour  }{'default'};
    return $self->{'colours'}->{'default'}{'default'} if exists $self->{'colours'}->{'default'}{'default'};
  }
  
  return defined $default ? $default : 'black';
}

sub draw_cigar_feature {
  my ($self, $params) = @_;
  my ($composite, $f, $h) = map $params->{$_}, qw(composite feature height);
  my $ref    = ref $f;
  my $length = $self->{'container'}->length;
  my $cigar;
  my $inverted = $params->{'inverted'} || 0;

  my $match_colour = $params->{'feature_colour'};
  if($inverted) {
    # Wash out matches when mismatches are to be emphasised
    $match_colour = $self->{'config'}->colourmap->mix($match_colour,'white',0.9);
  }
 
  if (!$ref) {
    warn sprintf 'DRAWINGCODE_CIGAR < %s > %s not a feature', $f, $self->label->text;
  } elsif ($ref eq 'SCALAR') {
    warn sprintf 'DRAWINGCODE_CIGAR << %s >> %s not a feature', $$f, $self->label->text;
  } elsif ($ref eq 'HASH') {
    warn sprintf 'DRAWINGCODE_CIGAR { %s } %s not a feature', join('; ', keys %$f), $self->label->text;
  } elsif ($ref eq 'ARRAY') { 
    warn sprintf 'DRAWINGCODE_CIGAR [ %s ] %s not a feature', join('; ', @$f), $self->label->text;
  }

  if ($ref eq 'Bio::EnsEMBL::Funcgen::ProbeFeature') {
    $f = Bio::EnsEMBL::DnaDnaAlignFeature->new(
      -slice        => $f->slice,
      -start        => $f->start,
      -end          => $f->end,
      -strand       => $self->strand,
      -hstart       => $f->start,
      -hend         => $f->end,
      -cigar_string => $f->cigar_string
    );
  }
  
  eval { $cigar = $f->cigar_string; };
  
  if ($@ || !$cigar) {
    my ($s, $e) = ($f->start, $f->end);
    $s = 1       if $s < 1;
    $e = $length if $e > $length; 
    
    $composite->push($self->Rect({
      x         => $s - 1,
      y         => $params->{'y'} || 0,
      width     => $e - $s + 1,
      height    => $h,
      colour    => $match_colour,
    }));
    
    return;
  }
  
  my $strand  = $self->strand;
  my $fstrand = $f->strand;
  my $hstrand = $f->hstrand;
  my $start   = $f->start;
  my $hstart  = $f->hstart;
  my $hend    = $f->hend;
  my ($slice_start, $slice_end, $tag1, $tag2, @delete);
  
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
  my @cigar = $f->cigar_string =~ /(\d*[MDImUXS=])/g;
     @cigar = reverse @cigar if $fstrand == -1;
  
  my $last_e = -1;
  foreach (@cigar) {
    # Split each of the {number}{Letter} entries into a pair of [ {number}, {letter} ] 
    # representing length and feature type ( 'M' -> 'Match/mismatch', 'I' -> Insert, 'D' -> Deletion )
    # If there is no number convert it to [ 1, {letter} ] as no-number implies a single base pair...
    my ($l, $type) = /^(\d+)([MDImUXS=])/ ? ($1, $2) : (1, $_);
    
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
    if ($type =~ /^[MmU=X]$/) {
      ($s, $e) = ($e, $s) if $s > $e; # Sort out flipped features
      
      next if $e < 1 || $s > $length; # Skip if all outside the box
      
      $s = 1       if $s < 1;         # Trim to area of box
      $e = $length if $e > $length;
      
      my $box = $self->Rect({
        x         => $s - 1,
        y         => $params->{'y'} || 0,
        width     => $e - $s + 1,
        height    => $h,
        colour    => $match_colour,
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
          y     => $strand == -1 ? 1 : 0 + ($params->{'y'} || 0),
          z     => $params->{'join_z'},
          col   => $params->{'join_col'},
          style => 'fill'
        });
        
        $self->join_tag($box, $tag, {
          x     => !$x,
          y     => $strand == -1 ? 1 : 0 + ($params->{'y'} || 0),
          z     => $params->{'join_z'},
          col   => $params->{'join_col'},
          style => 'fill'
        });
      }
      
      $composite->push($box);

      if($inverted && $last_e != -1) {
        $composite->push($self->Rect({
          x         => $last_e,
          y         => $params->{'y'} || 0,
          width     => $s - $last_e + 1,
          height    => $h,
          colour    => $params->{'feature_colour'},
        }));
        
      }
      $last_e = $e;

    } elsif ($type eq 'D') { # If a deletion temp store it so that we can draw after all matches
      ($s, $e) = ($e, $s) if $s < $e;
      
#      next if $e < 1 || $s > $length || $params->{'scalex'} < 1 ;  # Skip if all outside box
      next if $e < 1 || $s > $length;  # Skip if all outside box
      
      CORE::push @delete, $e;
    }
  }

  # Draw deletion markers
  foreach (@delete) {
    $composite->push($self->Rect({
      x         => $_,
      y         => $params->{'y'} || 0,
      width     => 0,
      height    => $h,
      colour    => $params->{'delete_colour'},
      absolutey => 1
    }));
  }
}

sub sort_features_by_priority {
  my ($self, %features) = @_;
  my @sorted     = keys %features;
  my $prioritize = 0;
  
  while (my ($k, $v) = each (%features)) {
    if ($v && @$v > 1 && ref($v->[1]) eq 'HASH' && $v->[1]{'priority'}) {
      $prioritize = 1;
      last;
    }
  }
  
  @sorted = sort { ($features{$b}->[1]{'priority'} || 0) <=> ($features{$a}->[1]{'priority'} || 0) } keys %features if $prioritize;
  
  return @sorted;
}

sub no_features {
  my $self  = shift;
  my $label = $self->my_empty_label;
  $self->errorTrack($label) if $label && 
    ($self->{'config'}->get_option('opt_empty_tracks') == 1
      || $self->{'my_config'}->get('show_empty_track') == 1 );
}

sub my_empty_label {
  my $self = shift;
  my $message;
  if ($self->can('get_data') || $self->can('features')) {
    $message = 'No features';
    my $track_name = $self->my_config('name');
    if ($track_name) {
      $message .= sprintf(' from %s', $track_name);
    }
    my $strand_flag = $self->my_config('strand');
    if ($strand_flag eq 'b') {
      $message .= ' on this strand';
    }
    else {
      $message .= ' in this region';
    }
  }
  return $message;
}

sub too_many_features {
  my $self  = shift;
  my $label = $self->my_label || 'features';
  $self->errorTrack("Too many $label in this region - please zoom in or select a histogram style");
}

sub no_track_on_strand {
  my $self = shift;
  return $self->errorTrack(sprintf 'No %s on %s strand in this region', $self->error_track_name, $self->strand == 1 ? 'forward' : 'reverse');
}

sub errorTrack {
  my ($self, $message, $x, $y,$mild) = @_;
  return if $self->error; ## Don't try to output more than one!
  $self->error(1);
  my %font   = $self->get_font_details('text', 1);
  my $length = $self->{'config'}->image_width;
  my @res    = $self->get_text_width(0, $message, '', %font);
  
  $self->push($self->Text({
    x             => $x || int(($length - $res[2]) / 2),
    y             => $y || 2,
    width         => $res[2],
    textwidth     => $res[2],
    height        => $res[3],
    halign        => 'center',
    colour        => $mild?'grey30':'red',
    text          => $message,
    absolutey     => 1,
    absolutex     => 1,
    absolutewidth => 1,
    pixperbp      => $self->{'config'}->transform_object->scalex,
    %font
  }));

  return $res[3];
}

#==============================================================================================================
# Bumping code support
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
  return scalar @{$self->{$key || '_bump'}{'array'} || []};
}

# compute the row to bump the feature to.. parameters are start/end in drawing (pixel co-ordinates)
sub bump_row {
  my ($self, $start, $end, $truncate_if_outside, $key) = @_;
  $key         ||= '_bump';
  ($end, $start) = ($start, $end) if $end < $start;
  $start         = 1 if $start < 1;
  my $row_length = $self->{$key}{'length'};
  
  return -1 if $end > $row_length && $truncate_if_outside; # used to not display partial text labels
  
  $end   = $row_length if $end > $row_length;
  $start = floor($start);
  $end   = ceil($end);
  
  my $length  = $end - $start + 1;
  my $element = '0' x $row_length;
  my $row     = 0;

  substr($element, $start, $length) = '1' x $length;
  
  while ($row < $self->{$key}{'rows'}) {
    if (!$self->{$key}{'array'}[$row]) { # We have no entries in this row - so create a new row
      $self->{$key}{'array'}[$row] = $element;
      return $row;
    }
    
    if (($self->{$key}{'array'}[$row] & $element) == 0) { # We already have a row, but the element fits so include it
      $self->{$key}{'array'}[$row] |= $element;
      return $row;
    }
    
    $row++; # Can't fit in on this row go to the next row..
  }
  
  return 1e9; # If we get to this point we can't draw the feature so return a very large number!
}

sub bump_sorted_row {
  my ($self, $start, $end, $truncate_if_outside, $key) = @_;
  $key         ||= '_bump';
  ($end, $start) = ($start, $end) if $end < $start;
  $start         = 1 if $start < 1;
  my $row_length = $self->{$key}{'length'};

  return -1 if $end > $row_length && $truncate_if_outside; # used to not display partial text labels

  $end   = $row_length if $end > $row_length;
  $start = floor($start);
  $end   = ceil($end);
  $end   = $start if $start > $end;
  
  my $row       = 0;
  my $max_rows  = $self->{$key}{'rows'};
  my $array_ref = $self->{$key}{'array'};

  while ($row < $max_rows) {
    if (!$array_ref->[$row]) { # We have no entries in this row - so create a new row
      $array_ref->[$row] = $end;
      return $row;
    }

    if ($array_ref->[$row] < $start) {
      $array_ref->[$row] = $end;
      return $row;
    }
    
    $row++; # Can't fit in on this row go to the next row..
  }

  return 1e9; # If we get to this point we can't draw the feature so return a very large number!
}

## Wrappers around bump utilities, which are now shared with new drawing code
sub mr_bump { return EnsEMBL::Draw::Utils::Bump::mr_bump(@_); }
sub do_bump { return EnsEMBL::Draw::Utils::Bump::do_bump(@_); }
sub text_bounds { return EnsEMBL::Draw::Utils::Bump::text_bounds(@_); }

sub max_label_rows {
  my $out = $_[0]->my_config('max_label_rows');
  return $out if $out;
  $out = $_[0]->supports_subtitles?2:1;
  return $out;
}

sub section {
  my $self = CORE::shift;

  return $self->my_config('section') || '';
}

sub section_zmenu { $_[0]->my_config('section_zmenu'); }
sub section_no_text { $_[0]->my_config('no_section_text'); }
sub section_lines { $_[0]->{'section_lines'}; }

sub section_text {
  if(@_>1) {
    $_[0]->{'section_text'} = $_[1];
    my @texts = @{$_[0]->wrap($_[1],$_[2],'Arial',8)};
    @texts = @texts[0..1] if @texts>2;
    $_[0]->{'section_lines'} = \@texts;
  }
  return $_[0]->{'section_text'};
}

sub section_height {
  my $self = shift;
  my $section_height = 0;
  if ($self->{'section_text'}) {
    $section_height = @{$self->{'section_lines'}||[]} == 1 ? 24 : 36; 
  }
  ## Set in track config so we can retrieve it in new drawing code
  $self->{'my_config'}->set('section_height', $section_height);
  return $section_height;
}


sub add_connections {
## Used by new drawing code to add 'tags'
  my ($self, $style) = @_;
  foreach (@{$style->connections||[]}) {
    next unless $_->{'glyph'};
    $self->join_tag($_->{'glyph'}, $_->{'tag'}, $_->{'params'});
  }
}

sub join_tag {
### join_tag joins between glyphsets in different tracks
### @param glyph          - glyph you've drawn...
### @param key            - Key for glyph
### @param x_pos          - X position in glyph (0-1)
### @param y_pos          - Y position in glyph (0-1) 0 nearest contigs
### @param $col           - colour to draw shape
### @param style String   - whether to fill or draw line
### @param z-index 
### @param href
### @param alt
### @param class
  my ($self, $glyph, $tag, $x_pos, $y_pos, $col, $style, $zindex, $href, $alt, $class) = @_;

  if (ref $x_pos eq 'HASH') {
    CORE::push @{$self->{'tags'}{$tag}}, {
      %$x_pos,
      'glyph' => $glyph
    };
  } else {
    CORE::push @{$self->{'tags'}{$tag}}, {
      'glyph' => $glyph,
      'x'     => $x_pos,
      'y'     => $y_pos,
      'col'   => $col,
      'style' => $style,
      'z'     => $zindex,
      'href'  => $href,
      'alt'   => $alt,
      'class' => $class
    };
  }
}

sub check {
  my $self   = CORE::shift;
  my ($name) = ref($self) =~ /::([^:]+)$/;
  return $name;
}

1;
