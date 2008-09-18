package EnsEMBL::Web::Document::Image;

use EnsEMBL::Web::File::Image;
use POSIX qw(floor ceil);
use Bio::EnsEMBL::DrawableContainer;
use Bio::EnsEMBL::VDrawableContainer;

our %formats = (qw(
  svg        SVG
  postscript PostScript
  pdf        PDF
));

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
    'cacheable'          => 'no',

    'introduction'       => undef,
    'tailnote'           => undef,
    'caption'            => undef,
    'button_title'       => undef,
    'button_name'        => undef,
    'button_id'          => undef,
    'format'             => 'png',
    'prefix'             => 'p',

    'image_formats'      => []
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
  foreach( keys %formats ) {
    $self->add_image_format( $_ ) if $object->param( "format_$_" ) eq 'on';
  }
}

#----------------------------------------------------------------------------
# FUNCTIONS FOR CONFIGURING AND CREATING KARYOTYPE IMAGES
#----------------------------------------------------------------------------

                                                                                
sub karyotype {
  my( $self, $object, $highs, $config ) = @_;
  my @highlights = ref($highs) eq 'ARRAY' ? @$highs : ($highs);
  
  if( $self->cacheable eq 'yes' ) {
    my $image = new EnsEMBL::Web::File::Image( $self->{'species_defs'} );
    $image->set_cache_filename( $self->image_type, $self->image_name );
    return if -e $image->filename."png" && -f $image->filename."png";
  }
  $config ||= 'Vkaryotype';
  my $chr_name;
  my $wuc = $object->image_config_hash( $config );
    
  # set some dimensions based on number and size of chromosomes    
  if( $wuc->{'_all_chromosomes'} eq 'yes' ) {
    $chr_name = 'ALL';
    #$wuc->container_width( $object->species_defs->MAX_CHR_LENGTH );
    $wuc->container_width( 300000000 );
    my $total_chrs = @{$object->species_defs->ENSEMBL_CHROMOSOMES};
	  $wuc->{'_rows'} = $object->param('rows') || ceil($total_chrs / 13 );
  } 
  else {
    $chr_name = $object->seq_region_name;
    $wuc->container_width( $object->seq_region_length );
    $wuc->{'_rows'} = 1;
  }

  if ($object->param('aggregate_colour')) {
    $wuc->{'_aggregate_colour'} = $object->param('aggregate_colour');
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
    { 'sa'=>$sa, 'ka'=>$ka, 'da'=>$da, 'chr'=>$chr_name }, $wuc, \@highlights
  );
  return undef; ## successful...
}
                                          
sub add_tracks {
                                                                                
  my ($self, $object, $config_name, $parser, $track_id) = @_;
                                                                                
  if ($object->seq_region_name eq 'ALL') {
    $self->do_chr_layout($object, $config_name);
  }
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
  if ($parser) { # use parsed userdata
    my $max_label = 0;
    foreach my $track ($parser->{'tracks'}) {
      foreach my $type (keys %{$track}) {
        my @features = $parser->fetch_features_by_tracktype($type);
        foreach my $row (@features) {
          my @array = @$row;
          foreach my $feature (@array) {
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
    $data = $object->retrieve_features($extra->{'features'}) unless $extra->{'feature_type'} eq 'Xref';
    foreach my $set (@$data) {
      foreach my $row (
        map { $_->[0] }
        sort { $a->[1] <=> $b->[1] || $a->[2] cmp $b->[2] || $a->[3] <=> $b->[3] }
        map { [$_, $_->{'region'} =~ /^(\d+)/ ? $1 : 1e20 , $_->{'region'},
$_->{'start'}] }
        @{$set->[0]}
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
  }
                                                                                
  # CONFIGURE POINTERS
                                                                                
  # set sensible defaults
  my $zmenu   = lc($object->param('zmenu'))    || 'on';
  my $color   = lc($object->param('col'))  || lc($extra->{'color'}) || 'red';
  # set style before doing chromosome layout, as layout may need 
  # tweaking for some pointer styles
  my $style   = lc($object->param('style')) || lc($extra->{'style'}) || 'rharrow'; 

  if ($config->{'_all_chromosomes'} eq 'yes') {
    $self->do_chr_layout($object, $config_name, $max_label);
  }

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
          $id = $row->{'label'};
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

# common code used by add_tracks and add_pointers (not private because presumably you might want a 'bare' karyotype with no additional data)
                                                                            
sub do_chr_layout {
    my ($self, $object, $config_name, $max_label) = @_;

    # CONFIGURE IMAGE SIZE AND LAYOUT
    my $chr;
    my $config  = $object->image_config_hash( $config_name );
    if ($config->{'_all_chromosomes'} eq 'yes') {
        $chr = 'ALL';
    }
    else {
        $chr = $self->chr_name;
    }
    my ($v_padding, $rows);
    # only allow user to override these if showing multiple chromosomes
    if ($chr eq 'ALL') {
        $v_padding = $object->param('v_padding')    || 50;
        $v_padding      = 20 unless $v_padding >= 20;
    }
    my $chr_length  = $object->param('chr_length')   || 300;
    $chr_length     = 100 unless $chr_length >= 100;
    my $h_padding   = $object->param('h_padding')    || 4;
    $h_padding      = 1 unless $h_padding >= 1;
    my $h_spacing   = $object->param('h_spacing')    || 6;
    $h_spacing      = 1 unless $h_spacing >= 1;
                                                                                
    # hack for text labels on feature pointers
    if ($object->param('style_0') eq 'text') {
        # don't show stain labels AND pointers!
        $config->{'_band_labels'} = 'off';
        # make space for pointer + text
        $h_spacing += $max_label * 5;
        $h_padding = '4';
    }

    # use these figures to calculate and set image dimensions
    $config->{'general'}->{$config_name}->{'_settings'}->{'width'} =
                $chr_length + $v_padding;
    $config->{'general'}->{$config_name}->{'Videogram'}->{'padding'} =
                $h_padding;
    $config->{'_rows'} = $rows;
    $config->{'_image_height'} = $chr_length;
    $config->container_width( $object->species_defs->MAX_CHR_LENGTH );
    
    return 1;
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
sub cacheable          : lvalue { $_[0]->{'cacheable'}; }

sub image_width        { $_[0]->drawable_container->{'config'}->get('_settings','width'); }
sub introduction       : lvalue { $_[0]->{'introduction'}; }
sub tailnote           : lvalue { $_[0]->{'tailnote'}; }
sub caption            : lvalue { $_[0]->{'caption'}; }
sub format             : lvalue { $_[0]->{'format'}; }
sub panel              : lvalue { $_[0]->{'panel'}; }

sub add_image_format  { push @{$_[0]->{'image_formats'}}, $_[1]; }

sub exists { 
  my $self = shift;
  return 0 unless $self->cacheable eq 'yes';
  my $image = new EnsEMBL::Web::File::Image( $self->{'species_defs'} );
  $image->set_cache_filename( $self->image_type, $self->image_name );
  return $image->exists;
}

sub render {
  my $self = shift;
  my $HTML = $self->introduction;
  ## Here we have to do the next bit which is to draw the image itself;
  my $image = new EnsEMBL::Web::File::Image( $self->{'species_defs'} );
  $image->dc = $self->drawable_container;
  if( $self->imagemap eq 'yes' ) {
    $image->{'img_map'} = 1;
  }
  if( $self->cacheable eq 'yes' ) {
    $image->set_cache_filename( $self->image_type, $self->image_name );
  } else {
    $image->set_tmp_filename( );
  }
  if ($self->button eq 'form') {
    $image->{'text'}  = $self->{'button_title'};
    $image->{'name'}  = $self->{'button_name'};
    $image->{'id'}    = $self->{'button_id'};
    my $image_html = $image->render_image_button();
       $image_html .= sprintf qq(<div style="text-align: center; font-weight: bold">%s</div>), $self->caption if $self->caption;
    $HTML .= sprintf '<form style="width: %spx" class="autocenter" action="%s" method="get"><div>%s</div><div class="autocenter">%s</div></form>',
      $image->{'width'},
      $self->{'URL'},
      join(
        '', map { sprintf '<input type="hidden" name="%s" id="%s%s" value="%s" />', $_, $_, $self->{'hidden_extra'}||$self->{'counter'},$self->{'hidden'}{$_} } 
        keys %{$self->{'hidden'}}
      ),
      $image_html;
    $self->{'counter'}++;
  } elsif ($self->button eq 'yes') {
    $image->{'text'} = $self->{'button_title'};
    $image->{'name'} = $self->{'button_name'};
    $image->{'id'}   = $self->{'button_id'};
    $HTML .= $image->render_image_button();
    $HTML .= sprintf qq(<div style="text-align: center; font-weight: bold">%s</div>), $self->caption if $self->caption;
  } elsif( $self->button eq 'drag' ) {
    $image->{'id'} = $self->{'prefix'} . "_$self->{'panel_number'}_i";
    my $tag = $image->render_image_tag();
    ## Now we have the image dimensions, we can set the correct DIV width
    $HTML .= $self->menu_container->render_html.$self->menu_container->render_js if $self->menu_container;
    ## continue with tag HTML
    ### This has to have a vertical padding of 0px as it is used in a number of places
    ### butted up to another container! - if you need a vertical padding of 10px add it
    ### outside this module!
    $HTML .= '<div style="text-align:center">'.
             '<div style="text-align:center;margin:auto;border:0px;padding:0px">'.
             sprintf( qq(<div class="drag_select" id="%s_%s" style="margin: 0px auto; border: solid 1px black; position: relative; width:%dpx">),
	       $self->{'prefix'},$self->{'panel_number'}, $image->{'width'}
	     ).
             $tag.
             ($self->imagemap eq 'yes' ? $image->render_image_map : '' ).
             '</div>'.
             ($self->caption ? sprintf( qq(<div style="text-align: center; font-weight: bold">%s</div>), $self->caption  ) : '' ).
             '</div>'.
             '</div>';
  } else {
    my $tag = $image->render_image_tag();
    ## Now we have the image dimensions, we can set the correct DIV width 
    if( $self->menu_container ) { 
      $HTML .= $self->menu_container->render_html;
      $HTML .= $self->menu_container->render_js;
    } 
    ## continue with tag HTML
    ### This has to have a vertical padding of 0px as it is used in a number of places
    ### butted up to another container! - if you need a vertical padding of 10px add it
    ### outside this module!
    $HTML .= sprintf '<div class="center" style="border:0px;margin:0px;padding:0px"><div style="text-align: center">%s</div>%s%s</div>',
               $tag,
               $self->imagemap eq 'yes' ? $image->render_image_map : '',
	       $self->caption ? sprintf( '<div style="text-align: center; font-weight: bold">%s</div>', $self->caption ) : '';
  }
  if( @{$self->{'image_formats'}} ) {
    my %URLS;
    foreach( sort @{$self->{'image_formats'}} ) {
      my $T = $image->render($_);
      $URLS{$_} = $T->{'URL'};
      $URLS{$_}.='.eps' if lc($_) eq 'postscript';
    }
    ## Add links for other image formats (right aligned in div)
     $HTML .= '<div style="text-align:right">'.join( '; ', map {
       qq(<a href="$URLS{$_}">View as $formats{$_}</a>)
     } @{$self->{'image_formats'}}).'.</div>';
  }
  $HTML .= $self->tailnote;
    
  $self->{'width'} = $image->{'width'};
  $self->{'species_defs'}->timer_push('Image->render ending',undef,'draw');
  return $HTML
}

1;

__END__
                                                                                
=head1 NAME
                                                                                
Document:Image
                                                                                
=head1 SYNOPSIS

This object creates and renders a dynamically-generated image using modules from ensembl-draw. It is called via one of the image methods in the Object module, thus:

  my $image          = $object->new_karyotype_image();

The image's parameters can then be set using the accessor methods (see below for a full list), e.g.

  $image->cacheable  = 'no';
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

=item cacheable     

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

