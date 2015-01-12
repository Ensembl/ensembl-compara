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

sub hub                { my $self = shift; return self->{'hub'};  }
sub component          { my $self = shift; return $self->{'component'}; }
sub height             :lvalue { $_[0]->{'height'};            }
sub format             :lvalue { $_[0]->{'format'};             }
sub toolbars           :lvalue { $_[0]->{'toolbars'};           }

sub has_toolbars  { 
### Checks if toolbars are wanted for this image
### @return Boolean
  return ($_[0]->{'toolbars'}{'top'} || $_[0]->{'toolbars'}{'bottom'}) ? 1 : 0; 
}

sub render_toolbar {} ## Stub - implement in children using methods below

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


1;
