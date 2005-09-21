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
    'image_name'         => undef,
    'cacheable'          => 'no',

    'introduction'       => undef,
    'tailnote'           => undef,
    'caption'            => undef,
    'button_title'       => undef,
    'button_name'        => undef,
    'button_id'          => undef,
    'format'             => 'png',

    'image_formats'      => []
  };
  bless $self, $class;
  return $self;
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
                                                                                
use Bio::EnsEMBL::VDrawableContainer;
                                                                                
sub karyotype {
  my( $self, $data, $highs, $config ) = @_;
  
  $config ||= 'Vkaryotype';
  my $chr_name;
  my $wuc = $data->user_config_hash( $config );
        
  if( $wuc->{'_all_chromosomes'} eq 'yes' ) {
    $chr_name = 'ALL';
    $wuc->container_width( $data->species_defs->MAX_CHR_LENGTH );
    my $total_chrs = @{$data->species_defs->ENSEMBL_CHROMOSOMES};
    # accept user input or set a sensible default
    $wuc->{'_rows'} ||= ceil($total_chrs / 13 ); 
  } else {
    $chr_name = $data->chr_name;
    $wuc->container_width( $data->length );
    $wuc->{'_rows'} = 1;
  }
  
  my( $sa, $ka, $da);
  eval {
    $sa = $data->database('core')->get_SliceAdaptor,
    $ka = $data->database('core')->get_KaryotypeBandAdaptor,
    $da = $data->database('core')->get_DensityFeatureAdaptor
  };
  return $@ if $@;
  $self->drawable_container = new Bio::EnsEMBL::VDrawableContainer(
    { 'sa'=>$sa, 'ka'=>$ka, 'da'=>$da, 'chr'=>$chr_name }, $wuc, $highs
  );
  return undef; ## successful...
}

# Adds chromosome row and spacing parameters to image configuration
                                                                                
sub do_chr_layout {
                                                                                
    my ($self, $object, $config_name, $max_label) = @_;
                                                                                
    # CONFIGURE IMAGE SIZE AND LAYOUT
    my $chr;
    my $config  = $object->user_config_hash( $config_name );
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
    if ($object->param('style') eq 'text') {
        # don't show stain labels AND pointers!
        $config->{'_band_labels'} = 'off';
        # make space for pointer + text
        $h_spacing += $max_label * 5;
        $h_padding = '4';
    }
    $config->{'general'}->{$config_name}->{'_settings'}->{'width'} =
                $chr_length + $v_padding;
    $config->{'general'}->{$config_name}->{'Videogram'}->{'padding'} =
                $h_padding;
    $config->{'_rows'} = $rows;
    $config->{'_image_height'} = $chr_length;
    $config->container_width( $object->species_defs->MAX_CHR_LENGTH );
    
    return 1;
}
                                                                                
#----------------------
                                                                                
# Sets the chromosome layout in the image configuration (via do_chr_layout),
# then adds feature density tracks to the image's configuration
                                                                                
sub add_tracks {
                                                                                
    my ($self, $object, $config_name, $parser) = @_;
                                                                                
    if ($object->chr_name eq 'ALL') {
        $self->do_chr_layout($object, $config_name);
    }
    my $config   = $object->user_config_hash( $config_name );
    
    # SELECT APPROPRIATE FEATURE SET(S)
    my $data;
    if ($parser) {
        # CREATE TRACKS
        my $pos = 10000;
        my $max_values = $parser->max_values();
        my $colour = $object->param('col') || 'purple';
        foreach my $track ( $parser->feature_types ) {
            push @{$config->{'general'}{$config_name}{'_artefacts'}}, "track_$track";
            $config->{'general'}{$config_name}{"track_$track"} = 
                {
                'on'            => 'on',
                'pos'           => ++$pos,
                'width'         => 50,
                'col'           => $colour,
                'manager'       => 'Vbinned',
                'label'         => $track,
                'bins'          => $parser->no_of_bins,
                'max_value'     => $max_values->{$track},
                'data'          => $parser->features_of_type( $track ),
                'maxmin'        => $object->param('maxmin'),
                },
        }
        if ($chr  eq 'ALL') {
            $config->{'_group_size'} = 1 + $parser->feature_types();
        } 
        # add selected standard tracks
        my @params = $object->param();
        my $box_value;
        foreach my $param (@params) {
            if ($param =~ /^track_/) {
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
    else {

        # ADD STANDARD DATA TRACKS
        my %features = map { ($_->analysis->logic_name() , 1) } @{
            $object->database('core')->get_DensityTypeAdaptor->fetch_all
            };
        foreach my $art ( $config->artefacts() ) {
            my @logicnames = ( split /\s+/,
                             $config->get( $art, 'logicname' ) );
            my @good_lnames = grep{$features{$_}} @logicnames;
            scalar( @good_lnames ) || next;
            $config->set( $art, 'on', 'on' );
            $config->set( $art, 'logicname', join( " ", @good_lnames ) );
        }
    }
                                                                                
    return 1;
}
                                                                                
#----------------------
                                                                                
# Sets the chromosome layout in the image configuration (via do_chr_layout),
# then creates a hash defining feature location pointers and returns a
# reference to that hash
                       
# N.B. This function does all the messy configuration of pointers and
# zmenus for you!

                                                         
sub add_pointers {
                                                                                
    my ($self, $object, $config_name, $zmenu_config, $parser) = @_;
    my $config   = $object->user_config_hash( $config_name );
    
    # CREATE DATA ARRAY FROM APPROPRIATE FEATURE SET
    my ($data, @data, $max_label, %chrs);
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
        $data = $object->retrieve_features;
        foreach my $row (
            map { $_->[0] }
            sort { $a->[1] <=> $b->[1] || $a->[2] cmp $b->[2] || $a->[3] <=> $b->[3] }
            map { [$_, $_->{'region'} =~ /^(\d+)/ ? $1 : 1e20 , $_->{'region'},
$_->{'start'}] }
            @$data
            ) {
            my $data_row = {
                'chr'    => $row->{'region'},
                'start'  => $row->{'start'},
                'end'    => $row->{'end'},
                'length' => $row->{'length'},
                'label'  => $row->{'label'},
                };
            push (@data, $data_row);
            $chrs{$row->{'region'}}++;                                         
        }
    }
                                                                                
    # CONFIGURE POINTERS
                                                                                
    # set sensible defaults
    my $zmenu   = lc($object->param('zmenu'))    || 'on';
    my $color   = lc($object->param('col'))      || 'red';
    my $style   = lc($object->param('style'))    || 'rharrow'; # set this before doing chromosome layout, as layout may need tweaking for some pointer styles
               
    if ($config->{'_all_chromosomes'} eq 'yes') {
        $self->do_chr_layout($object, $config_name, $max_label);
    }
    $config->{'general'}->{$config_name}->{'Videogram'}->{'style'} = $style;

    # CREATE POINTERS ('highlights')
    my %high;
    my $species = $object->species;
    foreach my $row ( @data ) {
        my $chr = $row->{'chr'};
        my $id  = $row->{'id'};
        my $point = {
            'start' => $row->{'start'},
            'end'   => $row->{'end'},
            'col'   => $color
            };
        if ($zmenu eq 'on') {
            $point->{'zmenu'} = {
                'caption'   => $zmenu_config->{'caption'},
                };
            my $order = 0;
            foreach my $entry (@{$zmenu_config->{'entries'}}) {
                my ($text, $key, $value);
                if ($entry eq 'contigview') {
                    $text = "Jump to $entry";
                    $value = sprintf("/$species/contigview?c=%s:%d;w=%d", $row->{'chr'}, int(($row->{'start'}+$row->{'end'})/2), $row->{'length'}+1000);
                    # add AffyProbe name(s) to URL to turn on tracks
                    if ($object->param('type') eq 'AffyProbe') {
                        my @affy_list = split(';', $row->{'label'});
                        foreach my $affy (@affy_list) {
                            my @affy_bits = split (':', $affy);
                            my $affy_id = @affy_bits[0];
                            $affy_id =~ s/\s//g;
                            $affy_id = lc($affy_id);
                            $affy_id =~ s/\W/_/g;
                            $affy_id =~ s/Plus_/+/i;
                            $value .= ';'.$affy_id.'=on';
                        }
                    }
                }
                elsif ($entry eq 'geneview') {
                    $text = "Jump to $entry";
                    $value = sprintf("/$species/geneview?gene=%s", $row->{'label'});
                }
                elsif ($entry eq 'label') {
                    $text = length( $row->{'label'} ) > 25 ? ( substr($row->{'label'}, 0, 22).'...') : $row->{'label'};
                    $value = '';
                }
                $key = sprintf('%03d', $order).':'.$text;
                $point->{'zmenu'}->{$key} = $value;
                $order++;
            }
        }
        if(exists $high{$chr}) {
            push @{$high{$chr}}, $point;
        } else {
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
  $image->set_cache_filename( $self->image_name );
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
    $image->set_cache_filename( $self->image_name );
  } else {
    $image->set_tmp_filename( );
  }
  if ($self->button eq 'form') {
    $image->{'text'}  = $self->{'button_title'};
    $image->{'name'}  = $self->{'button_name'};
    $image->{'id'}    = $self->{'button_id'};
    my $image_html = $image->render_image_button();
       $image_html .= sprintf qq(<div style="text-align: center; font-weight: bold">%s</div>), $self->caption if $self->caption;
    $HTML .= sprintf '<form style="width: %spx" class="autocenter" action="%s" method="get">%s<div class="autocenter">%s</div></form>',
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
    $HTML .= sprintf '<div class="center" style="border:0px;margin:0px;padding:0px">';
    $HTML .= qq(<div style="text-align: center">$tag</div>);
    if( $self->imagemap eq 'yes' ) {
      $HTML .= $image->render_image_map
    } 
## 
  $HTML .= sprintf qq(<div style="text-align: center; font-weight: bold">%s</div>), $self->caption if $self->caption;
    $HTML .= '</div>';
  }
  if( @{$self->{'image_formats'}} ) {
    my %URLS;
    foreach( sort @{$self->{'image_formats'}} ) {
      my $T = $image->render($_);
      $URLS{$_} = $T->{'URL'};
    }
    ## Add links for other image formats (right aligned in div)
     $HTML .= '<div style="text-align:right">'.join( '; ', map {
       qq(<a href="$URLS{$_}">View as $formats{$_}</a>)
     } @{$self->{'image_formats'}}).'.</div>';
  }
  $HTML .= $self->tailnote;
    
  $self->{'width'} = $image->{'width'};
  return $HTML
}

1;
