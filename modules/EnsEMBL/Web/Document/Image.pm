=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Document::Image;

### Parent class for visualisations

### Examples

### To use the blue toolbar in an image, pass a hashref e.g. 
### $args->{'toolbars'} = {'top' => 1, 'bottom' => 0}

use strict;

sub new {
### Generic constructor
  my ($class, $hub, $component, $args) = @_;

  my $self = {
    hub                => $hub,
    component          => $component,
    toolbars           => {},
    %$args,
  };

  bless $self, $class;
  return $self;
}

sub hub                { my $self = shift; return $self->{'hub'};  }
sub component          { my $self = shift; return $self->{'component'}; }
sub height             :lvalue { $_[0]->{'height'};            }
sub format             :lvalue { $_[0]->{'format'};             }
sub toolbars           :lvalue { $_[0]->{'toolbars'};           }
sub centred            :lvalue { $_[0]->{'centred'};            } 
sub image_name         :lvalue { $_[0]->{'image_name'};         }
sub image_type         :lvalue { $_[0]->{'image_type'};         }
sub introduction       :lvalue { $_[0]->{'introduction'};       }
sub tailnote           :lvalue { $_[0]->{'tailnote'};           }
sub caption            :lvalue { $_[0]->{'caption'};            }

sub image_width { 
  my $self = shift;
  if ($self->{'image_configs'}) {
    return $self->{'image_configs'}[0]->get_parameter('image_width'); 
  }
}

sub imagemap           :lvalue { $_[0]->{'imagemap'};           }
sub button             :lvalue { $_[0]->{'button'};             }
sub button_id          :lvalue { $_[0]->{'button_id'};          }
sub button_name        :lvalue { $_[0]->{'button_name'};        }
sub button_title       :lvalue { $_[0]->{'button_title'};       }

sub has_toolbars  { 
### Checks if toolbars are wanted for this image
### @return Boolean
  return ($_[0]->{'toolbars'}{'top'} || $_[0]->{'toolbars'}{'bottom'}) ? 1 : 0; 
}

sub render {} ## Stub - must be implemented in a child module

sub render_toolbar {
### Build the standard toolbar for a dynamic image and then render it
### @return Array (two strings of HTML for top and bottom toolbars)
  my $self = shift;

  ## Add icons specific to our standard dynamic images
  my $hub         = $self->hub;
  my $component   = $self->component;
  my $component_name = ref($component) ? $component->id : $component;
  my $viewconfig  = $hub->get_viewconfig($component_name);

  my $icons  = [];
  my $extra_html;

  if ($viewconfig) {
    push @$icons, $self->add_config_icon;

    if ($self->{'image_configs'}[0]->get_node('user_data')) {
      push @$icons, $self->add_userdata_icon;
    }

    push @$icons, $self->add_share_icon;
  }

  ## Increase/decrease image size icon  
  if (grep $_->image_resize, @{$self->{'image_configs'}}) {
    push @$icons, $self->add_resize_icon;
    $extra_html .= $self->add_resize_menu;
  }

  if ($self->{'export'}) {
    push @$icons, $self->add_image_export_icon;
    $extra_html .= $self->add_image_export_menu;
  }

  if ($self->{'data_export'}) {
    push @$icons, $self->add_export_icon;
  }

  if ($viewconfig) {
    push @$icons, $self->add_config_reset_icon;
  }

  if ($self->has_moveable_tracks) {
    push @$icons, $self->add_order_reset_icon;
  }

  return $self->_render_toolbars($icons, $extra_html);
}

sub _render_toolbars {
### Toolbar template, called by render_toolbar
### @param icons ArrayRef - configuration for each icon
### @param extra_html String (optional) - additional HTML for inclusion in toolbar
### @return Array - HTML for top and bottom toolbars
  my ($self, $icons, $extra_html) = @_;
  my @toolbars;
  my $icon_mappings = EnsEMBL::Web::Constants::ICON_MAPPINGS('image');
  return unless $icon_mappings;

  my $toolbar;
  foreach my $icon (@$icons) {
    $toolbar .= sprintf('<a href="%s" class="%s" title="%s" rel="%s"></a>',
                          $icon->{'href'},
                          $icon->{'class'},
                          $icon_mappings->{$icon->{'icon_key'}}{'title'},
                          $icon->{'rel'},
                        );
  }

  my @toolbars;
  if ($toolbar) {
    my $top    = $self->toolbars->{'top'} ? qq(<div class="image_toolbar top print_hide">$toolbar</div>$extra_html) : '';
    ### Force a toolbar if the image is long enough to disappear off most screens!
    my $bottom = ($self->toolbars->{'bottom'} || $self->height > 999) ? sprintf '<div class="image_toolbar bottom print_hide">%s</div>%s', $toolbar, $top ? '' : $extra_html : '';
    @toolbars = ($top, $bottom);
  }

  return @toolbars; 
}

sub add_config_icon {
### Configure icon for track configuration
### @return Hashref of icon parameters
  my $self = shift;
  my $hub         = $self->hub;
  my $component   = $self->component;
  my $config_url = $hub->url('Config', { action => $component, function => undef });
  return {
          'href'      => $config_url,
          'class'     => 'config modal_link force',
          'icon_key'  => 'config',
          'rel'       => 'modal_config_'.lc($component), 
          };
}

sub add_userdata_icon {
### Configure icon for userdata interface 
### @return Hashref of icon parameters
  my $self = shift;
  my $hub       = $self->hub;
  my $data_url  = $hub->url({ type => 'UserData', action => 'ManageData', function => undef });
  return {
          'href'      => $data_url,
          'class'     => 'data modal_link',
          'icon_key'  => 'userdata',
          'rel'       => 'modal_user_data',
          };
}

sub add_share_icon {
### Configure icon for share link popup 
### @return Hashref of icon parameters
  my $self = shift;
  my $hub        = $self->hub;
  my $component   = $self->component;
  my $share_url  = $hub->url('Share', { action => $component, function => undef, __clear => 1, create => 1, share_type => 'image', time => time });
  return {
          'href'      => $share_url,
          'class'     => 'share popup',
          'icon_key'  => 'share',
          };
}

sub add_export_icon {
### Configure icon for data export 
### @return Hashref of icon parameters
  my $self = shift;
  my $hub        = $self->hub;
  my $component   = $self->component;
  my $params = {
                   'type'      => 'DataExport', 
                   'action'    => $self->{'data_export'},
                   'data_type' => $hub->type,
                   'component' => $component,
                };
  foreach (@{$self->{'export_params'}||[]}) {
    if (ref($_) eq 'ARRAY') {
      $params->{$_->[0]} = $_->[1];
    }
    else {
      $params->{$_} = $hub->param($_);
    }
  }

  return {
          'href'      => $hub->url($params),
          'class'     => 'download modal_link',
          'icon_key'  => 'download',
          };
}

sub add_resize_icon {
### Configure icon for image resizing
### @return Hashref of icon parameters
  my $self = shift;
  my $hub  = $self->hub;
  return {
          'href'      => $hub->url,
          'class'     => 'resize popup',
          'icon_key'  => 'resize',
          };
}

sub add_resize_menu {
### Create HTML for image resize popup menu 
### @return String
  my $self = shift;
  my $hub  = $self->hub;

  # add best fit option
  my $resize_url = $hub->url;
  my $image_sizes = qq(<div><a href="$resize_url" class="image_resize"><div>Best Fit</div></a></div>);

  # get current image_width and provide size of +- 100 three times    
  for (my $counter = ($self->image_width-300);$counter <= ($self->image_width+300); $counter+=100) { 
    my $selected_size = 'class="current"' if($counter eq $self->image_width);
    my $hidden_width = ($counter < 500) ? "style='display:none'" : '';
    $image_sizes .= qq(<div $hidden_width><a href="$resize_url" class="image_resize"><div $selected_size>$counter px</div></a></div>);
  }

  return qq(
       <div class="toggle image_resize_menu">
          <div class="header">Resize image to:</div>
          $image_sizes    
       </div>    
    );
}

sub add_image_export_icon {
### Configure icon for image export
### @return Hashref of icon parameters
  my $self = shift;
  my $hub  = $self->hub;
  return {
          'href'      => $self->_export_url.'pdf',
          'class'     => 'export popup '.$self->{'export'},,
          'icon_key'  => 'image',
          };
}

sub _export_url {
### Helper function to build export URL
### @return String
  my $self = shift;
  my $url  = $ENV{'REQUEST_URI'};
  $url  =~ s/;$//;
  $url .= ($url =~ /\?/ ? ';' : '?') . 'export=';
  return $url;
}

sub add_image_export_menu {
### Create HTML for image export popup menu 
### @return String
  my $self = shift;
  my $hub  = $self->hub;
  return unless $self->{'export'};

  my $menu;
  my @formats = (
      { f => 'pdf',     label => 'PDF'},
      { f => 'svg',     label => 'SVG' },
      { f => 'eps',     label => 'PostScript' },
      { f => 'png-5',   label => 'PNG (x5)' },
      { f => 'png-2',   label => 'PNG (x2)' },
      { f => 'png',     label => 'PNG' },
      { f => 'png-0.5', label => 'PNG (x0.5)' },
      { f => 'gff',     label => 'Text (GFF)', text => 1 }
  );

  splice @formats, 3, 0, { f => 'png-10',  label => 'PNG (x10)' } unless $self->height > 32000; ## PNG renderer will crash if image too tall!

  my $url = $self->_export_url;

  foreach (@formats) {
    my $href = $url . $_->{'f'};

    if ($_->{'text'}) {
      next if $self->{'export'} =~ /no_text/;

      $menu .= qq(<div><div>$_->{'label'}</div><a href="$href;download=1"><img src="/i/16/download.png" alt="download" title="Download" /></a></div>);

    } elsif ($_->{'f'} eq 'pdf') {
      # option not to include pdf export
      next if $self->{'export'} =~ /no_pdf/;

      $menu .= qq(
          <div>
            <div>$_->{'label'}</div>
            <a class="view" href="$href" rel="external"><img src="/i/16/eye.png" alt="view" title="View image" /></a>
            <a href="$href;download=1"><img src="/i/16/download.png" alt="download" title="Download" /></a>
          </div>
      );

    } else {
      $menu .= qq(
          <div>
            <div>$_->{'label'}</div>
            <a class="view" href="$href" rel="external"><img src="/i/16/eye.png" alt="view" title="View image" /></a>
            <a href="$href;download=1"><img src="/i/16/download.png" alt="download" title="Download" /></a>
          </div>
      );
    }
  }

  $menu = qq(
      <div class="toggle iexport_menu">
        <div class="header">Export as:</div>
        $menu
      </div>
  );

  return $menu;
}

sub add_config_reset_icon {
### Configure icon for resetting track configuration
### @return Hashref of icon parameters
  my $self = shift;
  my $hub  = $self->hub;
  my $url = $hub->url({qw(type Ajax action config_reset __clear 1)});
  return {
          'href'      => $url,
          'class'     => 'config-reset _reset',
          'icon_key'  => 'reset_config',
          };
}
sub add_order_reset_icon {
### Configure icon for resetting track order
### @return Hashref of icon parameters
  my $self = shift;
  my $hub  = $self->hub;
  my $url = $hub->url({qw(type Ajax action order_reset __clear 1)});
  return {
          'href'      => $url,
          'class'     => 'order-reset _reset',
          'icon_key'  => 'reset_order',
          };
}


##########################################################
# Other functionality shared between e.g. GD and Genoverse
##########################################################

sub set_button {
  my ($self, $type, %pars) = @_;

  $self->button           = $type;
  $self->{'button_id'}    = $pars{'id'}     if exists $pars{'id'};
  $self->{'button_name'}  = $pars{'id'}     if exists $pars{'id'};
  $self->{'button_name'}  = $pars{'name'}   if exists $pars{'name'};
  $self->{'URL'}          = $pars{'URL'}    if exists $pars{'URL'};
  $self->{'hidden'}       = $pars{'hidden'} if exists $pars{'hidden'};
  $self->{'button_title'} = $pars{'title'}  if exists $pars{'title'};
  $self->{'hidden_extra'} = $pars{'extra'}  if exists $pars{'extra'};
}


1;
