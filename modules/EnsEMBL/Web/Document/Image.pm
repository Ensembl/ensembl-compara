package EnsEMBL::Web::Document::Image;

use strict;

use EnsEMBL::Web::TmpFile::Image;
use POSIX qw(floor ceil);
use Bio::EnsEMBL::DrawableContainer;
use Bio::EnsEMBL::VDrawableContainer;

sub new {
  my( $class, $species_defs, $panel_name ) = @_;
  my $self = {
    'panel'              => $panel_name,
    'species_defs'       => $species_defs,
    'drawable_container' => undef,
    'menu_container'     => undef,
    'imagemap'           => 'no',
    'image_type'         => 'image',
    'image_name'         => undef,

    # Deprecated
    # 'cacheable'          => 'no',

    'introduction'       => undef,
    'tailnote'           => undef,
    'caption'            => undef,
    'button_title'       => undef,
    'button_name'        => undef,
    'button_id'          => undef,
    'image_id'           => undef,
    'format'             => 'png',
    'prefix'             => 'p',

  };
  bless $self, $class;
  return $self;
}

sub prefix {
  ### a
  my ($self, $value) = @_;
  if ($value) {
    $self->{'prefix'} = $value;
  }
  return $self->{'prefix'};
}
sub set_extra {
  my( $self, $object ) = @_;
}

#----------------------------------------------------------------------------
# FUNCTIONS FOR CONFIGURING AND CREATING KARYOTYPE IMAGES
#----------------------------------------------------------------------------

                                                                                
sub karyotype {
  my( $self, $object, $highs, $config_name ) = @_;
  my @highlights = ref($highs) eq 'ARRAY' ? @$highs : ($highs);
  
  $config_name ||= 'Vkaryotype';
  my $chr_name;

  my $image_config = $object->image_config_hash( $config_name );
  my $view_config   = $object->get_viewconfig;
  warn "$image_config $view_config -> $config_name";

  # set some dimensions based on number and size of chromosomes
  if( $image_config->get_parameter('all_chromosomes') eq 'yes' ) {
    $chr_name = 'ALL';
    my $total_chrs = @{$object->species_defs->ENSEMBL_CHROMOSOMES};
    my $rows;
    if ($view_config) {
      $rows = $view_config->get('rows');
      my $chr_length = $view_config->get('chr_length') || 200;
      my $total_length = $chr_length + 25;
      $image_config->set_parameters({
        'image_height'  => $chr_length,
        'image_width'   => $total_length,
      });
    }
    $rows = ceil($total_chrs / 18 ) unless $rows;
    
    $image_config->set_parameters({ 
      'container_width' => $object->species_defs->MAX_CHR_LENGTH,
      'rows'            => $rows,
      'slice_number'  => '0|1',
    });
  }
  else {
    $chr_name = $object->seq_region_name;
    $image_config->set_parameters({
      'container_width' => $object->seq_region_length,
      'slice_number'    => '0|1'
    });
    $image_config->{'_rows'} = 1;
  }

  if ($object->param('aggregate_colour')) {
    $image_config->{'_aggregate_colour'} = $object->param('aggregate_colour');
  }
  
  # get some adaptors for chromosome data
  my( $sa, $ka, $da);
  my $species = $object->param('species') || undef;
  eval {
    $sa = $object->database('core', $species)->get_SliceAdaptor,
    $ka = $object->database('core', $species)->get_KaryotypeBandAdaptor,
    $da = $object->database('core', $species)->get_DensityFeatureAdaptor
  };
  return $@ if $@;

  # create the container object and add it to the image
  $self->drawable_container = new Bio::EnsEMBL::VDrawableContainer(
    { 'sa'=>$sa, 'ka'=>$ka, 'da'=>$da, 'chr'=>$chr_name }, $image_config, \@highlights
  );
  return undef; ## successful...
}
                                          
sub add_tracks {
### TODO - MOVE THIS TO IMAGE CONFIG?                                                                            
  my ($self, $object, $config_name, $parser, $track_id) = @_;
           
  my $config   = $object->image_config_hash( $config_name );
    
  # SELECT APPROPRIATE FEATURE SET(S)
  my $data;
  if ($parser) { # we have use data
    # CREATE TRACKS
    my $track_data;
    my $pos = 10000;
    my $max_values = $parser->max_values();

    ## get basic configuration
    my ($colour, $track_name); 
    my $manager = 'Vbinned';
    if ($track_id) {
      $track_name = $object->param("track_name_$track_id");
      $colour = $object->param("col_$track_id");
      my $style = $object->param("style_$track_id");
      $manager .= '_'.$style unless $style eq 'line';
    }
    else {
      $track_name = "track_$track_id";
      $colour = $object->param('col') || 'purple';
    }

    if ($object->param("merge_$track_id")) { ## put all data in one track
      my %all_features;
      my $max;
      push @{$config->{'general'}{$config_name}{'_artefacts'}}, "$track_name";
      my @types = $parser->feature_types;
      my $bins = $parser->no_of_bins;
      foreach my $type (@types) {
        my %features = %{$parser->features_of_type($type)};
        foreach my $chr (keys %features) {
          my @results = @{$features{$chr}};
          for (my $i=0; $i < $bins; $i++) {
            my $score = $results[$i];
            $all_features{$chr}[$i] += $score;
          }
        }
        my $current_max = $max_values->{$type};
        $max = $current_max if $max < $current_max;
      }
      $config->{'general'}{$config_name}{$track_name} = 
        {
          'on'            => 'on',
          'pos'           => ++$pos,
          'width'         => 50,
          'col'           => $colour,
          'manager'       => $manager,
          'label'         => $track_name,
          'bins'          => $parser->no_of_bins,
          'max_value'     => $max,
          'data'          => \%all_features,
          'maxmin'        => $object->param('maxmin'),
          };
      $config->{'_group_size'} = 2;
    }
    else {
      my $track_count = 0;
      foreach my $track ( $parser->feature_types ) {
        push @{$config->{'general'}{$config_name}{'_artefacts'}}, "track_$track";
        $config->{'general'}{$config_name}{"track_$track"} = 
        {
          'on'            => 'on',
          'pos'           => ++$pos,
          'width'         => 50,
          'col'           => $colour,
          'manager'       => $manager,
          'label'         => $track,
          'bins'          => $parser->no_of_bins,
          'max_value'     => $max_values->{$track},
          'data'          => $parser->features_of_type( $track ),
          'maxmin'        => $object->param('maxmin'),
          };
        $track_count++;
      }
      $config->{'_group_size'} = 1 + $parser->feature_types();
    }

    # add selected standard tracks
    my @params = $object->param();
    my $box_value;
    foreach my $param (@params) {
      if ($param =~ /^track_/ && !($param =~ /^track_name/)) {
       $config->{'_group_size'}++;
        if ($object->param($param) ne 'on') {
          $box_value = 'off';
        }
        else {
          $box_value = 'on';
        }
        $param =~ s/^track_//;
        $config->set($param, 'on', $box_value);
      }
    } 
  } 
  else { # display standard tracks
    my %features = map { ($_->analysis->logic_name() , 1) } @{
        $object->database('core')->get_DensityTypeAdaptor->fetch_all
    };
    foreach my $art ( $config->artefacts() ) {
	  my @logicnames;
	  if (ref($config->get( $art, 'logicname' )) eq 'ARRAY') {
		  my $array_ref = $config->get( $art, 'logicname' );
		  @logicnames = join(' ',@$array_ref);
	  }
	  else {
		@logicnames = ( split /\s+/,
                          $config->get( $art, 'logicname' ) );
	  }
      my @good_lnames = grep{$features{$_}} @logicnames;
      if( @logicnames  ) {
        if( @good_lnames ) {
          $config->set( $art, 'on', 'on' );
          $config->set( $art, 'logicname', join( " ", @good_lnames ) );
        } else {
          $config->set( $art, 'on', 'off' );
        }
      } elsif( $config->is_available_artefact( $art ) ) {
        $config->set( $art, 'on', 'on' );
      }
    }
  }
  return 1;
}
                                                                                
                                                                                
sub add_pointers {
                                                                                
  my ($self, $object, $extra) = @_;
  my $config_name = $extra->{'config_name'};
  my $config   = $object->image_config_hash($config_name);

  # CREATE DATA ARRAY FROM APPROPRIATE FEATURE SET
  my ($data, @data, $max_label, %chrs);
  my $parser = $extra->{'parser'};

  #warn           "Parser:     $parser";
  if ($parser) { # use parsed userdata
    my $max_label = 0;
    foreach my $track ($parser->{'tracks'}) {
      #warn         "  Track:    $track ",keys %$track;
      foreach my $type (keys %{$track}) {
        #warn       "    Type:   $type";
        my @features = $parser->fetch_features_by_tracktype($type);
        foreach my $row (@features) {
          #warn     "      Row:  $row";
          my @array = @$row;
          foreach my $feature (@array) {
            #warn   "        F:  $feature";
            my $data_row = {
                           'chr'   => $feature->seqname(),
                           'start' => $feature->rawstart(),
                           'end'   => $feature->rawend(),
                           'label' => $feature->id(),
                           'gene_id' => $feature->id(),
                            };
            push (@data, $data_row);
            $chrs{$feature->seqname()}++;                                         
            # track max label length for use with 'text' option
            my $label_len = CORE::length($feature->id());
            if ($label_len > $max_label) {
              $max_label = $label_len;
            }
          }
        }
      }
    }
  }
  else { # get features for this object
    $data = $extra->{'features'};
    foreach my $row (
      map { $_->[0] }
      sort { $a->[1] <=> $b->[1] || $a->[2] cmp $b->[2] || $a->[3] <=> $b->[3] }
      map { [$_, $_->{'region'} =~ /^(\d+)/ ? $1 : 1e20 , $_->{'region'},
$_->{'start'}] }
      @$data
      ) {
      my $data_row = {
          'chr'       => $row->{'region'},
          'start'     => $row->{'start'},
          'end'       => $row->{'end'},
          'length'    => $row->{'length'},
          'label'     => $row->{'label'},
          'gene_id'   => $row->{'gene_id'},
        };
      push (@data, $data_row);
      $chrs{$row->{'region'}}++;                                         
    }
  }
                                                                                
  # CONFIGURE POINTERS
                                                                                
  # set sensible defaults
  my $zmenu   = lc($object->param('zmenu'))    || 'on';
  my $zmenu_config;
  my $color   = lc($object->param('col'))  || lc($extra->{'color'}) || 'red';
  # set style before doing chromosome layout, as layout may need 
  # tweaking for some pointer styles
  my $style   = lc($object->param('style')) || lc($extra->{'style'}) || 'rharrow'; 

  # CREATE POINTERS ('highlights')
  my %high = ('style' => $style);
  my $species = $object->species;
  foreach my $row ( @data ) {
    my $chr = $row->{'chr'};
    my $point = {
            'start' => $row->{'start'},
            'end'   => $row->{'end'},
            'id'    => $row->{'label'},
            'col'   => $color,
            };
    if ($zmenu eq 'on') {
      $zmenu_config = $extra->{'zmenu_config'};
      $point->{'zmenu'} = {
                'caption'   => $zmenu_config->{'caption'},
           };
      my $order = 0;
      foreach my $entry (@{$zmenu_config->{'entries'}}) {
        my ($text, $key, $value);
        if ($entry eq 'contigview') {
          $text = "Jump to $entry";
          $value = sprintf("/$species/contigview?c=%s:%d;w=%d", $row->{'chr'}, int(($row->{'start'}+$row->{'end'})/2), $row->{'length'}+1000);
          # AffyProbe name(s) in URL turn on tracks in contigview
          if ($object->param('type') eq 'AffyProbe') {
            my @affy_list = split(';', $row->{'label'});
            foreach my $affy (@affy_list) {
              my @affy_bits = split (':', $affy);
              my $affy_id = $affy_bits[0];
              $affy_id =~ s/\s//g;
              $affy_id = lc($affy_id);
              $affy_id =~ s/\W/_/g;
              $affy_id =~ s/Plus_/+/i;
              $value .= ';'.$affy_id.'=on';
            }
          }
          $key = sprintf('%03d', $order).':'.$text;
          $point->{'zmenu'}->{$key} = $value;
          $order++;
        }
        elsif ($entry eq 'geneview') {
          foreach my $gene (@{$row->{'gene_id'}}) {
            if (scalar(@{$row->{'gene_id'}}) > 1) {
              $text = "$entry: $gene";
            }
            else {
              $text = "Jump to $entry";
            }
            $value = "/$species/geneview?gene=$gene";
            $key = sprintf('%03d', $order).':'.$text;
            $point->{'zmenu'}->{$key} = $value;
            $order++;
          }
        }
        elsif ($entry eq 'label') {
          $text = length( $row->{'label'} ) > 25 ? ( substr($row->{'label'}, 0, 22).'...') : $row->{'label'};
          $value = '';
          $key = sprintf('%03d', $order).':'.$text;
          $point->{'zmenu'}->{$key} = $value;
          $order++;
        }
        elsif ($entry eq 'userdata') {
          my $id = $row->{'label'};
          $key = sprintf('%03d', $order).':'.$id;
          $point->{'zmenu'}->{$key} = '';
          $order++;
        }
      }
    }

    # OK, we now have a complete pointer, so add it to the hash of arrays
    if(exists $high{$chr}) {
      push @{$high{$chr}}, $point;
    } 
    else {
      $high{$chr} = [ $point ];
    }
  }
                                                                                
  return \%high;
}

#############################################################################


sub object             : lvalue { $_[0]->{'object'}; }
sub drawable_container : lvalue { $_[0]->{'drawable_container'}; }
sub menu_container     : lvalue { $_[0]->{'menu_container'}; }
sub imagemap           : lvalue { $_[0]->{'imagemap'}; }
sub set_button {
  my( $self, $type, %pars ) = @_;
  $self->button          = $type;
  $self->{'button_id'}   = $pars{'id'}     if exists $pars{'id'};
  $self->{'button_name'} = $pars{'id'}     if exists $pars{'id'};
  $self->{'button_name'} = $pars{'name'}   if exists $pars{'name'};
  $self->{'URL'}         = $pars{'URL'}    if exists $pars{'URL'};
  $self->{'hidden'}      = $pars{'hidden'} if exists $pars{'hidden'};
  $self->{'button_title'} = $pars{'title'} if exists $pars{'title'};
  $self->{'hidden_extra'} = $pars{'extra'} if exists $pars{'extra'};
}
sub button             : lvalue { $_[0]->{'button'}; }
sub button_id          : lvalue { $_[0]->{'button_id'}; }
sub button_name        : lvalue { $_[0]->{'button_name'}; }
sub button_title       : lvalue { $_[0]->{'button_title'}; }
sub image_type         : lvalue { $_[0]->{'image_type'}; }
sub image_name         : lvalue { $_[0]->{'image_name'}; }
sub image_id           : lvalue { $_[0]->{'image_id'}; }

# Deprecated:
# sub cacheable          : lvalue { $_[0]->{'cacheable'}; }

sub image_width        { $_[0]->drawable_container->{'config'}->get_parameter('image_width'); }
sub introduction       : lvalue { $_[0]->{'introduction'}; }
sub tailnote           : lvalue { $_[0]->{'tailnote'}; }
sub caption            : lvalue { $_[0]->{'caption'}; }
sub format             : lvalue { $_[0]->{'format'}; }
sub panel              : lvalue { $_[0]->{'panel'}; }


## TODO: Obsolete code, remove
#sub exists { 
#  my $self = shift;
#  return 0 unless $self->cacheable eq 'yes';
#  my $image = new EnsEMBL::Web::File::Image( $self->{'species_defs'} );
#  $image->set_cache_filename( $self->image_type, $self->image_name );
#  return $image->exists;
#}

####################################################################################################
##
## Renderers
##
####################################################################################################

sub extraHTML {
  my $self = shift;
  my $extra = '';

  if( $self->{'image_id'} ) {
    $extra .= qq(id="$self->{'image_id'}" )
  }

  if( $self->{'img_map'} ) {
    if( $self->{'id'} ) {
      $extra .= qq(usemap="#$self->{'id'}_map" );
    } else {
      $extra .= qq(usemap="#$self->{'token'}" );
    }
  }
  return $extra;
}

sub extraStyle {
  my $self = shift;
  my $extra = '';
  if( $self->{'border'} ) {
    $extra .= sprintf qq(border: %s %dpx %s;),
              $self->{'border_colour'} || '#000', $self->{'border'},
              $self->{'border_style'}||'solid'; 
  }
  return $extra;
}

sub render_image_tag {
  my $self  = shift;
  my $image = shift;

  my $HTML;

  if ($image->width > 5000) {
    my $url = $image->URL;
    $HTML = qq(
               <p style="text-align:left">
                 The image produced was ".$image->width." pixels wide,
                 which may be too large for some web browsers to display.
                 If you would like to see the image, please right-click (MAC: Ctrl-click)
                 on the link below and choose the 'Save Image' option from the pop-up menu.
                 Alternatively, try reconfiguring KaryoView, either merging the features
                 into a single track (step 1) or selecting one chromosome at a time (Step 3).</p>
               <p><a href="$url">Image download</a></p>
            );
  } else {
    $HTML = sprintf '<img src="%s" alt="%s" title="%s" style="width: %dpx; height: %dpx; %s display: block" %s />',
                       $image->URL,
                       $self->{'button_title'},
                       $self->{'button_title'},
                       $image->width,
                       $image->height,
                       $self->extraStyle,
                       $self->extraHTML;

    $self->{'width'}  = $image->width;
    $self->{'height'} = $image->height;
  }

  return $HTML;
} 

sub render_image_button {
  my $self = shift;
  my $image = shift;

  my $HTML = sprintf
    '<input style="width: %dpx; height: %dpx; %s display: block" type="image" name="%s" id="%s" src="%s" alt="%s" title="%s" %s />',
             $image->width,
             $image->height,
             $self->extraStyle,
             $self->{'button_name'},
             $self->{'image_id'} || $self->{'button_name'},
             $image->URL,
             $self->{'button_title'},
             $self->{'button_title'};

  return $HTML;
} 

sub render_image_map {
  my $self  = shift;
  my $image = shift;

  my $imagemap = $self->drawable_container->render('imagemap');

  my $map_name = $self->{'image_id'} ? "$self->{'image_id'}_map" : $image->token;

  return sprintf(
            qq(<map name="%s" id="%s">\n%s\n</map>),
            $map_name,
            $map_name,
            $imagemap
  );
}

sub render {
  my( $self, $format ) = @_;

  if( $format ) {
    print $self->drawable_container->render( $format );
    return;
  }

  my $HTML = $self->introduction;

  ## Here we have to do the next bit which is to draw the image itself;
  my $image   = new EnsEMBL::Web::TmpFile::Image;
  my $content = $self->drawable_container->render('png');

  $image->content($content);
  $image->save;
  
  if ($self->button eq 'form') {

    $self->{'image_id'} = $self->{'button_id'};
    my $image_html      = $self->render_image_button($image);
    
    $self->{'hidden'}{'total_height'} = $image->height;
    $image_html .= sprintf qq(<div style="text-align: center; font-weight: bold">%s</div>),
                   $self->caption
                     if $self->caption;

    $HTML .= sprintf '<form style="width: %spx" class="autocenter" action="%s" method="get"><div>%s</div><div class="autocenter">%s</div></form>',
      $image->width,
      $self->{'URL'},
      join(
        '', map {
              sprintf '<input type="hidden" name="%s" id="%s%s" value="%s" />',
                      $_,
                      $_,
                      $self->{'hidden_extra'} || $self->{'counter'},
                      $self->{'hidden'}{$_}
            } keys %{$self->{'hidden'}},
      ),
      $image_html;
    $self->{'counter'}++;

  } elsif ($self->button eq 'yes') {

      $self->{'image_id'} = $self->{'button_id'};
      $HTML .= $self->render_image_button($image);
      $HTML .= sprintf qq(<div style="text-align: center; font-weight: bold">%s</div>),
                       $self->caption
                         if $self->caption;

  } elsif( $self->button eq 'drag' ) {

    $self->{'image_id'} = $self->{'prefix'} . "_$self->{'panel_number'}_i";

    my $tag = $self->render_image_tag($image);
    ## Now we have the image dimensions, we can set the correct DIV width
    $HTML .= $self->menu_container->render_html . $self->menu_container->render_js
               if $self->menu_container;

    ## continue with tag HTML
    ### This has to have a vertical padding of 0px as it is used in a number of places
    ### butted up to another container! - if you need a vertical padding of 10px add it
    ### outside this module!
    my $URL = $ENV{'REQUEST_URI'};
       $URL =~ s/;$//;
       $URL .= $URL =~ /\?/ ? ';' : '?';
       $URL .= 'export=pdf';
           
    $HTML .= '<div style="text-align:center">' .
             '<div style="text-align:center;margin:auto;border:0px;padding:0px">' .
             sprintf( qq(<div class="drag_select" id="%s_%s" style="margin: 0px auto; border: solid 1px black; position: relative; width:%dpx">),
      	       $self->{'prefix'},
      	       $self->{'panel_number'},
      	       $image->width
      	     ) .
             $tag .
             ($self->imagemap eq 'yes' ? $self->render_image_map($image) : '' ) .
             '</div>' .
             ( $self->{'export'} ? qq{<div class="$self->{'export'}" style="width:$image->{'width'}px;"><a href="$URL">Export</a></div>} : '' ) .
             ( $self->caption ? sprintf(qq(<div style="text-align: center; font-weight: bold">%s</div>), $self->caption) : '' ) .
             '</div></div>';
  } else {
    
    my $tag = $self->render_image_tag($image);
    ## Now we have the image dimensions, we can set the correct DIV width 
    if( $self->menu_container ) { 
      $HTML .= $self->menu_container->render_html;
      $HTML .= $self->menu_container->render_js;
    } 
    ## continue with tag HTML
    ### This has to have a vertical padding of 0px as it is used in a number of places
    ### butted up to another container! - if you need a vertical padding of 10px add it
    ### outside this module!
    $HTML .= sprintf '<div class="center" style="border:0px;margin:0px;padding:0px"><div style="text-align: center">%s</div>%s%s%s</div>',
               $tag,
               $self->imagemap eq 'yes'
                 ? $self->render_image_map($image)
                 : '',
               $self->{'export'}
                 ? '<div style="text-align:right; background-color; red;">EXPORT</div>'
                 : '',
               $self->caption
                 ? sprintf('<div style="text-align: center; font-weight: bold">%s</div>', $self->caption)
                 : '';
  }

  $HTML .= $self->tailnote;
    
  $self->{'width'} = $image->width;
  $self->{'species_defs'}->timer_push('Image->render ending', undef, 'draw');

  return $HTML
}

1;

__END__
                                                                                
=head1 NAME
                                                                                
Document:Image
                                                                                
=head1 SYNOPSIS

This object creates and renders a dynamically-generated image using modules from ensembl-draw. It is called via one of the image methods in the Object module, thus:

  my $image          = $self->new_karyotype_image();

The image's parameters can then be set using the accessor methods (see below for a full list), e.g.

  $image->image_name = "feature-$species";
  $image->imagemap   = 'yes';

Finally, additional features can be added to the image where appropriate:

  my $pointers = $image->add_pointers( $object,
                            {'config_name'  => 'Vkaryotype',
                             'zmenu_config' => $zmenu_config,
                             'feature_type' => 'Gene',
                             'color'        => $object->param("color")
                             'style'        => $object->param("style"),
                            }
                        );
  $image->karyotype($object, [$pointers], 'Vkaryotype');


=head1 DESCRIPTION
                                                                                
                                                                                
=head1 METHODS
                                                                                
=head2 B<new>
                                                                                
Description:    Constructor method for the Document::Image object
                                                                                
Arguments:      [1] class name, [2] a SpeciesDefs object, [3] the name of the Panel object the image belongs to
                                                                                
Returns:        a Document::Image object

=head2 B<set_extra>
                                                                                
Description:    
                                                                                
Arguments:     
                                                                                
Returns:        

=head2 B<karyotype>
                                                                                
Description:    Creates a VDrawableContainer object configured to display a karyotype, and assigns it to the 'drawable_container' property of the Image object
                                                                                
Arguments:      [1] A Document::Image object, [2] a ref to an array of sequence features, [3] a ref to an array of "highlights", i.e. tracks or pointers, [4] a configuration name for retrieving the user's configuration
                                                                                
Returns:        undef on success

=head2 B<do_chr_layout>
                                                                                
Description:    Adds chromosome row and spacing parameters to image configuration. This method is called by both C<add_tracks> and C<add_pointers>, so does not need to be called separately for images that display feature highlights.
                                                                                
Arguments:     [1] a Document::Image object, [2] a Proxy::Object (i.e. sequence data), [3] a configuration name (see C<karyotype>), [4] a maximum label size (optional, for use mainly with text-based highlights) 
                                                                                
Returns:        true

=head2 B<add_tracks>
                                                                                
Description:    Adds feature density tracks to a karyotype image, from the user's own data and/or the user's selection from some standard Ensembl data
                                                                                
Arguments:     [1] a Document::Image object, [2] a Proxy::Object (i.e. sequence
data), [3] a configuration name (see C<karyotype>), [4] a parser object containing user data (optional)
                                                                                
Returns:        true

=head2 B<add_pointers>
                                                                                
Description:   Creates a hash of feature location pointers  from the user's own data and/or the user's selection from some standard Ensembl data. Note that this method does all the messy configuration of pointers and zmenus so you don't have to! 
                                                                                
Arguments:     [1] a Document::Image object, [2] a Proxy::Object (i.e. sequence
data), [3] a ref to a hash of other options: config_name, zmenu_config, parser, color, style (the latter two for the appearance of the pointers). Color, style and zmenu_config can be set via this hash or via a web form; if neither is used, sensible defaults are provided by the method.
                                                                                
Returns:        a reference to the hash of pointers

=head2 B<accessor methods>

=over 4

=item object

=item drawable_container

=item menu_container

=item imagemap

=item set_button

=item button             

=item button_id         

=item button_name      

=item button_title   

=item image_name     

=item image_id

=item image_width  

=item introduction   

=item tailnote      

=item caption      

=item format      

=item panel      

=back
                                                                            
=head2 B<add_image_format>
                                                                                
Description:    
                                                                                
Arguments:     
                                                                                
Returns:        

=head2 B<exists>
                                                                                
Description:    
                                                                                
Arguments:     
                                                                                
Returns:        

=head2 B<render>
                                                                                
Description:    
                                                                                
Arguments:     
                                                                                
Returns:        

=head1 BUGS AND LIMITATIONS
                                                                                
None known at present.
                                                                                
                                                                                
=head1 AUTHOR
                                                                                
Anne Parker, Ensembl Web Team
Support enquiries: helpdesk\@ensembl.org
                                                                                
=head1 COPYRIGHT
                                                                                
See http://www.ensembl.org/info/about/code_licence.html
                                                                                
=cut

