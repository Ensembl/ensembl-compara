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

package EnsEMBL::Draw::VDrawableContainer;

### Base class for Ensembl genomic images in "vertical" configuration
### i.e. whole chromosomes and karyotypes
### Collects the individual glyphsets required for the image (e.g. tracks)
### and manages the overall image settings

use strict;

use EnsEMBL::Draw::GlyphSet::Videogram;

sub new {
  my $class  = shift;
  my $self   = $class->_init(@_);
  my $legend = {};

  ########## loop over all the glyphsets the user wants:
  foreach (@{$self->{'contents'}}) {
    my ($container, $config) = @$_;
    
    $container->{'web_species'} ||= $ENV{'ENSEMBL_SPECIES'};
    
    my @chromosomes = ($container->{'chr'});
    my @configs     = @{$config->get_tracks};
    my $scalex      = $config->get_parameter('image_height') / $config->get_parameter('container_width');
    my $pos         = 100000;
    my $tmp         = {};
    my $flag        = 0;
    my (@glyphsets, %chr_glyphset_counts);
    
    if ($config->get_parameter('all_chromosomes') eq 'yes') { 
      @chromosomes = @{$config->species_defs->get_config($container->{'web_species'}, 'ENSEMBL_CHROMOSOMES') || []};
      @chromosomes = reverse @chromosomes if $container->{'format'} && $container->{'format'} eq 'pdf'; # reverse the order for drawing
      $flag        = 1;
    }

    $config->texthelper->scalex($scalex);

    my $transform_obj = $config->transform_object;

    $transform_obj->scalex($scalex);
    $transform_obj->absolutescalex(1);
    $transform_obj->translatex($transform_obj->translatex + $config->get_parameter('top_margin'));

    foreach my $chr (@chromosomes) {
      $container->{'chr'} = $chr;
      
      foreach my $row_config (@configs) {
        next if $row_config->get('matrix') eq 'column';
        
        my $display = $row_config->get('display') || ($row_config->get('on') eq 'on' ? 'normal' : 'off');
        
        if ($display eq 'default') {
          my $column_key = $row_config->get('column_key');
          
          if ($column_key) {
            my $column  = $config->get_node($column_key);
               $display = $column->get('display') || ($column->get('on') eq 'on' ? 'normal' : 'off') if $column;
          }
        }
        
        $config->set_parameter('band_labels', 'off') if $display =~ /highlight/; ## Turn off band labels if we have pointer tracks 
        
        next if $display eq 'off' || $display =~ /highlight/;
        
        my $option_key = $row_config->get('option_key');
        
        next if $option_key && $config->get_node($option_key)->get('display') ne 'on';
        
        my $classname = "$self->{'prefix'}::GlyphSet::" . $row_config->get('glyphset');
        
        next unless $self->dynamic_use($classname);
        
        my $glyphset;
        
        ## create a new glyphset for this row
        eval {
          $glyphset = $classname->new({
	          container  => $container,
	          config     => $config,
	          my_config  => $row_config,
	          strand     => 0,
	          highlights => $self->{'highlights'},
            display    => $display,
            legend     => $legend,
          });
        };
        
        if ($@ || !$glyphset) {
          my $reason = $@ || "No reason given just returns undef";
          warn "GLYPHSET: glyphset $classname failed (@{[$self->{container}{web_species}]}/$ENV{'ENSEMBL_SCRIPT'} at " . gmtime() . "\nGLYPHSET:  $reason";
	        next;
        }
        
        $glyphset->{'chr'}    = $chr;
        $glyphset->{'data'} ||= $self->{'storage'}{$row_config->id};
        
        $glyphset->render_normal;

        if (@{$glyphset->{'glyphs'} || []}) {
	        push @glyphsets, $glyphset;
	        $chr_glyphset_counts{$chr}++;
        } elsif (!$row_config->get('hide_empty')) {
	        push @glyphsets, $glyphset;
	        $chr_glyphset_counts{$chr}++;
        }
      }
    }

    ## Firstly lets work how many entries to draw per row!
    ## Then work out the minimum start for each of these rows
    ## We then shift up all these points up by that many base 
    ## pairs to close up any gaps

    my ($max_gs_chr)    = sort { $b <=> $a } values %chr_glyphset_counts;
    my $glyphsets       = @glyphsets;
    my $group_size      = $config->get_parameter('group_size') || $max_gs_chr;
    my $entries_per_row = $config->get_parameter('columns')    || (int(($glyphsets/$group_size - 1) / ($config->get_parameter('rows') || 1) + 1) * $group_size);
    $entries_per_row    = $max_gs_chr if $max_gs_chr > $entries_per_row;
    my $spacing         = $self->{'spacing'};
    my $entry_no        = 0;
    my $row_count       = 0;
    my $row_index       = 0;
    my $yoffset         = 0;
    my $current_chr     = undef;
    my (@min, @max);
    
    $config->set_parameter('max_height', 0);
    $config->set_parameter('max_width',  0);
    
    foreach my $glyphset (@glyphsets) {
      if ($current_chr ne $glyphset->{'chr'}) { ## Can we fit all the chr stuff in!
        $row_count += $chr_glyphset_counts{$glyphset->{'chr'}};
        
        if ($row_count > $entries_per_row) {
          $row_index++;
          $row_count = 0;
        }
        
        $current_chr = $glyphset->{'chr'};
      }
      
      $glyphset->{'row_index'} = $row_index;
      
      next unless defined $glyphset->minx;
      
      $min[$row_index] = $glyphset->minx if !defined $min[$row_index] || $min[$row_index] > $glyphset->minx;
    }
    
    ## Close up gap!

    my $translateX = shift @min;
    
    $transform_obj->translatex($transform_obj->translatex - $translateX * $scalex);
    
    my $xoffset   = -$translateX * $scalex;
    my $row_index = 0;

    foreach my $glyphset (@glyphsets) {
      if ($row_index != $glyphset->{'row_index'}) {  ## We are on a new row - so reset the yoffset [horizontal] to 0 
        my $translateX = shift @min;
        
        $row_index = $glyphset->{'row_index'};
        $yoffset   = 0;
        $xoffset  += $config->image_width - $translateX * $scalex;
        
        ## Shift down - and then close up gap!
        $transform_obj->translatex($transform_obj->translatex + $config->image_width - $translateX * $scalex);
      }
      
      $config->set_parameter('max_width', $xoffset + $config->get_parameter('image_width'));
      
      ########## set up the label for this strip 
      ########## first we get the max width of label in characters
      my $feature_type_1 = $glyphset->my_config('feature_type')   || ($glyphset->my_config('keys') ? $glyphset->my_config('keys')->[0] : undef);
      my $feature_type_2 = $glyphset->my_config('feature_type_2') || ($glyphset->my_config('keys') ? $glyphset->my_config('keys')->[1] : undef);
      my $label_1        = $glyphset->my_config('label')          || ($feature_type_1 ? $glyphset->my_colour($feature_type_1, 'text')  : undef);
      my $label_2        = $glyphset->label2 || $glyphset->my_config('label_2') || ($feature_type_2 ? $glyphset->my_colour($feature_type_2, 'text')  : undef);
      
      $label_1 = $glyphset->{'chr'} if $glyphset->{'my_config'}->id eq 'Videogram' && $flag;
      
      my $gw  = length(length $label_2 > length $label_1 ? $label_2 : $label_1);
      
      if ($gw > 0) {
        ########## and convert it to pels
        $gw = $config->texthelper->width('Small');
        my $gh = $config->texthelper->height('Small');
        
        ########## If the '_label' position is not 'above' move the labels below the image
        my $label_x  = $config->get_parameter('label') eq 'above' ? 0 : $config->get_parameter('image_height');
        $label_x    += 4 - $config->get_parameter('top_margin');
        my $label_y  = ($glyphset->maxy + $glyphset->miny - $gw) / 2;
        my $colour_1 = $glyphset->my_config('colour')   || ($feature_type_1 ? $glyphset->my_colour($feature_type_1, 'label') : undef);
        my $colour_2 = $glyphset->my_config('colour_2') || ($feature_type_2 ? $glyphset->my_colour($feature_type_2, 'label') : undef);

        my $chr = $glyphset->{'chr'};
        my $href = $self->{'config'}->hub->url("ZMenu",{
          action => 'VChrom',
          chr => $chr,
        });
        if ($label_1) {
          my $chr_colour_key = $config->get_parameter('chr_colour_key');
          $colour_1 = $chr_colour_key->{$chr}->{'label'} if $chr_colour_key && $chr_colour_key->{$chr};
          $glyphset->push($glyphset->Text({
            x         => $label_x / $scalex,
            y         => ($glyphset->maxy + $glyphset->miny - length($label_1) * $gw) / 2,
            height    => $gw * length($label_1),
            width     => $gh / $scalex,
            font      => 'Small',
            text      => $label_1,
            absolutey => 1,
            colour    => $colour_1,
            href      => $href,
          }));
        }
        
        if ($label_2) {
          $glyphset->push($glyphset->Text({
            x         => ($label_x + 2 + $config->texthelper->height('Tiny')) / $scalex,
            y         => ($glyphset->maxy + $glyphset->miny - length($label_2) * $gw) / 2,
            height    => $gw * length($label_2),
            width     => $gh / $scalex,
            font      => 'Small',
            text      => $label_2,
            absolutey => 1,
            colour    => $colour_2,
            href      => $href,
          }));
        }
      }
      
      ########## remove any whitespace at the top of this row
      $transform_obj->translatey(-$glyphset->miny + $spacing/2 + $yoffset);
      $glyphset->transform;
      
      ########## translate the top of the next row to the bottom of this one
      $yoffset += $glyphset->height + $spacing;
      $config->set_parameter('max_height',  $yoffset + $spacing) if $yoffset + $spacing > $config->get_parameter('max_height');
    }
    
    $self->{'glyphsets'} = \@glyphsets;
  }

  return $self;
}

sub _init {
  my $class    = shift;
  my $contents = shift;
  
  if (ref $contents eq 'ARRAY') {
    my $T = [];
    
    while (@$contents) {
      push @$T, [ splice @$contents, 0, 2 ];
    }
    
    $contents = $T;
  } else {
    $contents = [[ $contents, shift ]];
  }

  my ($highlights, $strandedness, $spacing, $storage) = @_;

  my $self = {
    glyphsets               => [],
    config                  => $contents->[0][1],
    storage                 => $storage,
    prefix                  => 'EnsEMBL::Draw',
    contents                => $contents,
    highlights              => $highlights   || [],
    spacing                 => $spacing      || $contents->[0][1]->get_parameter('spacing') || 0,
    strandedness            => $strandedness || 0,
    __extra_block_spacing__ => 0,
  };

  $self->{'strandedness'} = 1 if $self->{'config'}->get_parameter('text_export');

  bless $self, $class;
  return $self;
}

########## render does clever drawing things
sub render {
  my ($self, $type) = @_;
  
  ########## build the name/type of render object we want
  my $renderer_type = qq(EnsEMBL::Draw::VRenderer::$type);
  ########## dynamic require of the right type of renderer

  return unless $self->dynamic_use($renderer_type);

  ########## big, shiny, rendering 'GO' button
  my $renderer = $renderer_type->new(
    $self->{'config'},
    $self->{'vc'},
    $self->{'glyphsets'}
  );
  
  return $renderer->canvas;
}

sub config {
  my ($self, $config) = @_;
  $self->{'config'} = $config if defined $config;
  return $self->{'config'};
}

sub glyphsets { return @{$_[0]->{'glyphsets'}}; }

sub dynamic_use {
  my ($self, $classname) = @_;
  my ($parent_namespace, $module) = $classname =~ /^(.*::)(.*?)$/;
  
  no strict 'refs';
  return 1 if $parent_namespace->{"$module::"}; # return if already used
  
  eval "require $classname";
  
  if ($@) {
    warn "VDrawableContainer: failed to use $classname\nVDrawableContainer: $@";
    return 0;
  }
  
  $classname->import;
  return 1;
}

1;
