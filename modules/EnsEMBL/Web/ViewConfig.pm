package EnsEMBL::Web::ViewConfig;

use strict;

use CGI::Cookie;
use Digest::MD5 qw(md5_hex);
use HTML::Entities qw(encode_entities);
use URI::Escape qw(uri_escape uri_unescape);

use EnsEMBL::Web::Form;
use EnsEMBL::Web::OrderedTree;

use base qw(EnsEMBL::Web::Root);

sub new {
  my ($class, $type, $action, $hub) = @_;

  my $self = {
    hub                 => $hub,
    species             => $hub->species,
    species_defs        => $hub->species_defs,
    real                => 0,
    nav_tree            => 0,
    title               => undef,
    _classes            => [],
    _options            => {},
    _image_config_names => {},
    default_config      => '_page',
    can_upload          => 0,
    has_images          => 0,
    _form               => undef,
    _form_id            => sprintf('%s_%s_configuration', lc $type, lc $action),
    _form_layouts       => {},
    url                 => undef,
    tree                => new EnsEMBL::Web::OrderedTree,
    custom              => $ENV{'ENSEMBL_CUSTOM_PAGE'} ? $hub->session->custom_page_config($type) : [],
    type                => $type,
    action              => $action
  };
  
  bless $self, $class;
  return $self;
}

sub hub            :lvalue { $_[0]->{'hub'};            }
sub default_config :lvalue { $_[0]->{'default_config'}; }
sub real           :lvalue { $_[0]->{'real'};           }
sub nav_tree       :lvalue { $_[0]->{'nav_tree'};       }
sub url            :lvalue { $_[0]->{'url'};            }
sub title          :lvalue { $_[0]->{'title'};          }
sub can_upload     :lvalue { $_[0]->{'can_upload'}      }
sub has_images     :lvalue { $_[0]->{'has_images'};     }
sub altered        :lvalue { $_[0]->{'altered'};        } # Set to one if the configuration has been updated
sub storable       :lvalue { $_[0]->{'storable'};       } # Set whether this ViewConfig is changeable by the User, and hence needs to access the database to set storable do $view_config->storable = 1; in SC code
sub custom         :lvalue { $_[0]->{'custom'};         }
sub species       { return $_[0]->{'species'};          }
sub species_defs  { return $_[0]->{'species_defs'};     }
sub is_custom     { return $ENV{'ENSEMBL_CUSTOM_PAGE'}; }
sub type          { return $_[0]->{'type'};             }
sub action        { return $_[0]->{'action'};           }
sub tree          { return $_[0]->{'tree'};             }

# Value indidates that the track can be configured for DAS (das) or not (nodas)
sub add_image_configs {
  my ($self, $image_config) = @_;
  
  foreach (keys %$image_config) {
    $self->{'_image_config_names'}->{$_} = $image_config->{$_};
    $self->can_upload = 1 if $image_config->{$_} eq 'das';
    $self->has_images = 1 if $image_config->{$_} !~ /^V/
  }
}

sub has_image_config {
  my $self   = shift;
  my $config = shift;
  return exists $self->{'_image_config_names'}{$config};
}
sub has_image_configs {
  my $self = shift;
  return keys %{$self->{'_image_config_names'}||{}};
}

sub image_configs {
  my $self = shift;
  return %{$self->{'_image_config_names'}||{}};
}

sub _set_defaults {
  my $self = shift;
  my %defs = @_;

  foreach my $key (keys %defs) {
    $self->{'_options'}{$key}{'default'} = $defs{$key};
  }
}

sub _clear_defaults {
  my $self = shift;
  $self->{'_options'} = {};
}

# Clears the listed default values
sub _remove_defaults {
  my $self = shift;
  foreach my $key (@_) {
    delete $self->{'_options'}{$key};
  }
}

sub options { 
  my $self = shift;
  return keys %{$self->{'_options'}};
}

sub has_form {
  my $self = shift;
  return $self->{'_form'} || $self->has_images || grep $_->can('form'), @{$self->{'_classes'}};
}

sub get_form {
  my $self = shift;
  $self->{'_form'} ||= EnsEMBL::Web::Form->new($self->{'_form_id'}, $self->url, 'post', 'configuration std check');
  return $self->{'_form'};
}

sub add_fieldset {
  my ($self, $legend, $class) = @_;
  
  return $self->add_form_layout({'heading' => $legend, 'class' => $class });
}

sub add_form_layout {
  my ($self, $params) = @_;
  my $layout_type = {
    'onecolumn'=> $self->get_form->ONE_COLUMN,
    'matrix'   => $self->get_form->MATRIX,
  };
  
  (my $div_class = $params->{'heading'}) =~ s/ /_/g; 
   
  return $self->{'_form_layouts'}{ $params->{'heading'} } if $params->{'heading'} && exists $self->{'_form_layouts'}{ $params->{'heading'} };

  my $layout = $self->get_form->set_layout(
    $params->{'type'} && exists $layout_type->{ $params->{'type'} }
      ? $layout_type->{ $params->{'type'} } 
      : $self->get_form->TWO_COLUMN
    )
  ;
  $layout->set_heading($params->{'heading'}) if $params->{'heading'};
  $layout->set_attribute('class', $div_class) if $params->{'heading'};
  $layout->set_attribute('class', $params->{'class'}) if $params->{'class'};
  $layout->set_attribute('class', 'vc_div');

  $self->{'_form_layouts'}{ $params->{'heading'} } = $layout if $params->{'heading'};
  $self->tree->create_node(undef, { url => '#', availability => 1, caption => $params->{'heading'}, class => $div_class }) if $self->nav_tree;
  return $layout;
}

sub get_fieldset {
  my ($self, $i) = @_;
  
  if ($i =~ /^[0-9]+$/) {
    return exists $self->get_form->layouts->[ $i ] ? $self->get_form->layouts->[ $i ] : undef;
  }
  
  return exists $self->{'_form_layouts'}{ $i } ? $self->{'_form_layouts'}{ $i } : undef;
}

sub add_form_element {
  my ($self, $element) = @_;
  
  my $value = $self->get($element->{'name'});
  if ($element->{'type'} =~ /CheckBox/) {
    $element->{'checked'} = $value eq $element->{'value'} ? 1 : 0;
  } elsif (!exists $element->{'value'}) {
    $element->{'value'} = $value;
  }
  
  my $layout = $self->get_form->layouts->[1]; #layouts->[0] is added to form by default... so that would have not been added by viewConfig
  unless (defined $layout) {
    $layout = $self->add_fieldset('Display options');
    $self->tree->create_node(undef, { url => '#', availability => 1, caption => 'Display options', class => 'generic' }) if $self->nav_tree;
  }
  $self->get_form->add_element(%$element);
}

# Loop through the parameters and update the config based on the parameters passed
sub update_from_input {
  my $self  = shift;
  my $input = $self->hub->input;
  
  return $self->reset if $input->param('reset');
  
  my $flag = 0;
  my $altered;
  
  foreach my $key ($self->options) {
    my @values = $input->param($key);
    
    if (scalar @values && $values[0] ne $self->{'_options'}{$key}{'user'}) {
      $flag = 1;
      
      if (scalar @values > 1) {
        $self->set($key, \@values);
      } else {
        $self->set($key, $values[0]);
      }
      
      $altered ||= $key if $values[0] !~  /^(off|no)$/;
    }
  }
  
  $self->altered = $altered || 1 if $flag;
}

# Loop through the parameters and update the config based on the parameters passed
sub update_from_config_strings {
  my ($self, $r) = @_;
  
  my $hub     = $self->hub;
  my $session = $hub->session;
  my $input   = $hub->input;
  my $species = $hub->species;
  my $updated = 0;
  my $params_removed;
  
  if ($input->param('config')) {
    foreach my $v (split /,/, $input->param('config')) {
      my ($k, $t) = split /=/, $v, 2;
      
      if ($k =~ /^(cookie|image)_width$/) {
        my $cookie_host  = $self->species_defs->ENSEMBL_COOKIEHOST;
        
        # Set width
        if ($t != $ENV{'ENSEMBL_IMAGE_WIDTH'}) {
          my $cookie = new CGI::Cookie(
            -name    => 'ENSEMBL_WIDTH',
            -value   => $t,
            -domain  => $cookie_host,
            -path    => '/',
            -expires => $t =~ /\d+/ ? 'Monday, 31-Dec-2037 23:59:59 GMT' : 'Monday, 31-Dec-1970 00:00:01 GMT'
          );
          
          $r->headers_out->add('Set-cookie' => $cookie);
          $r->err_headers_out->add('Set-cookie' => $cookie);
          $self->altered = 1;
        }
      }
      
      $self->set($k, $t);
    }

    if ($self->altered) {
      $session->add_data(
        type     => 'message',
        function => '_info',
        code     => 'configuration',
        message  => 'Your configuration has changed for this page',
      );
    }
    
    $params_removed = 1;
    $input->delete('config');
  }
  
  foreach my $name ($self->image_configs) {
    my @values = split /,/, $input->param($name);
    
    if (@values) {
      $input->delete($name); 
      $params_removed = 1;
    }
    
    if ($name eq 'contigviewbottom' || $name eq 'cytoview') {
      foreach my $v ($input->param('data_URL')) {
        push @values, sprintf 'url:%s=normal', uri_escape($v);
        $params_removed = 1; 
      }
      
      $input->delete('data_URL');
      
      foreach my $v ($input->param('add_das_source')) {
        my $server = $v =~ /url=(https?:[^ +]+)/ ? $1 : '';
        my $dsn    = $v =~ /dsn=(\w+)/ ? $1 : '';
        
        push @values, sprintf 'das:%s=normal', uri_escape("$server/$dsn");
        $params_removed = 1;
      }
      
      $input->delete('add_das_source');
    }
    
    if (@values) {
      my $image_config = $hub->get_imageconfig($name, $name);
      
      next unless $image_config;
      
      foreach my $v (@values) {
        my ($key, $renderer) = split /=/, $v, 2;
        
        if ($key =~ /^(\w+)[\.:](.*)$/) {
          my ($type, $p) = ($1, $2);
          
          if ($type eq 'url') {
            $p = uri_unescape($p);
            my @path = split(/\./, $p);
            my $ext = $path[-1] eq 'gz' ? $path[-2] : $path[-1];
            my $format = uc($ext);
            
            # We have to create a URL upload entry in the session
            my $code = md5_hex("$species:$p");
            my $n    =  $p =~ /\/([^\/]+)\/*$/ ? $1 : 'un-named';
            
            $session->set_data(
              type    => 'url',
              url     => $p,
              species => $species,
              code    => $code, 
              name    => $n,
              format  => $format,
              style   => $format,
            );
            
            $session->add_data(
              type     => 'message',
              function => '_info',
              code     => 'url_data:' . md5_hex($p),
              message  => sprintf('Data has been attached to your display from the following URL: %s', encode_entities($p))
            );
            
            # We then have to create a node in the user_config
            $image_config->_add_flat_file_track(undef, 'url', "url_$code", $n, 
              sprintf('Data retrieved from an external webserver. This data is attached to the %s, and comes from URL: %s', encode_entities($n), encode_entities($p)),
              'url' => $p
            );
            
            $updated += $image_config->update_track_renderer("url_$code", $renderer);
          } elsif ($type eq 'das') {
            $p = uri_unescape($p);
            
            if (my $error = $session->add_das_from_string($p, { ENSEMBL_IMAGE => $name }, { display => $renderer })) {
              $session->add_data(
                type     => 'message',
                function => '_warning',
                code     => 'das:' . md5_hex($p),
                message  => sprintf('You attempted to attach a DAS source with DSN: %s, unfortunately we were unable to attach this source (%s)', encode_entities($p), encode_entities($error))
              );
            } else {
             $session->add_data(
                type     => 'message',
                function => '_info',
                code     => 'das:' . md5_hex($p),
                message  => sprintf('You have attached a DAS source with DSN: %s to this display', encode_entities($p))
              );
              
              $updated++;
            }
          }
        } else {
          $updated += $image_config->update_track_renderer($key, $renderer, 1);
        }
      }
    }
  }
  
  if ($updated) {
    $session->add_data(
      type     => 'message',
      function => '_info',
      code     => 'image_config',
      message  => 'The link you followed has made changes to the tracks displayed on this page',
    );
  }
  
  $self->altered = 1 if $updated;
  $session->store;

  return $params_removed ? join '?', $r->uri, $input->query_string : undef;
}

# Delete a key from the user settings
sub delete {
  my ($self, $key) = @_;
  return unless exists $self->{'_options'}{$key}{'user'};
  $self->altered = 1;
  delete $self->{'_options'}{$key}{'user'};
}

# Delete all keys from user settings
sub reset {
  my ($self) = @_;
  
  foreach my $key ($self->options) {
    next unless exists $self->{'_options'}{$key}{'user'};
    $self->altered = 1;
    delete $self->{'_options'}{$key}{'user'};
  }
}

sub add_class {
  my ($self, $class) = @_;
  
  if ($self->dynamic_use($class)) {
    my $method_name = "${class}::init";
    
    eval { no strict 'refs'; &$method_name($self); };
    
    if ($@) {
      my $message = "Undefined subroutine &$method_name called";
      
      if ($@ =~ /$message/) {
        warn "ViewConfig: init not defined in $class\n";
      } else {
        warn "ViewConfig: init call on $class failed:\n$@";
      }
    } else {
      push @{$self->{'_classes'}}, $class;
      $self->real = 1;
      return 1;
    }
  } else {
    my $error = $self->dynamic_use_failure($class);
    warn "ViewConfig: failed to require $class:\n  $error" unless $error =~ /^Can't locate/;
  }
}

sub form {

  my ($self, $object, $no_extra_bits) = @_;
  
  foreach my $classname (@{$self->{'_classes'}}) {
    my $method = $classname . '::form';
    
    eval { no strict 'refs'; &$method($self, $object); };
    warn $@ if $@; # TODO: proper error exception
  }
   
  foreach my $layout (@{$self->get_form->layouts}) {
  
    next unless ref($layout) =~ /twocolumn/i;
    
    my $inputs = $layout->get_elements_by_tag_name('input');
    next unless scalar @$inputs;
    next if $inputs->[0]->get_attribute('name') eq 'select_all'; 
    
    my $count = { map {$_ => 0} qw(checkbox text password) };
    for (@$inputs) {
      $count->{ $_->get_attribute('type') }++ if exists $count->{ $_->get_attribute('type') };
    }
    
    if ($count->{'checkbox'} > 1 && [ sort { $count->{ $b } <=> $count->{ $a } } keys %$count ]->[0] eq 'checkbox') {
      my $field = $layout->add_field({
        'label'     => 'Select/deselect all',
        'class'     => 'select_all',
        'elements'  => [{
          'type'      => 'checklist',
          'name'      => 'select_all',
          'options'   => [{
            'value'   => 'select_all',
          }],
        }],
      });
      $layout->inner_div->insert_at_beginning($field);
    } 
  }
  
  return if $no_extra_bits;
  
  if ($self->has_images) {
    my $fieldset = $self->get_fieldset('Display options') || $self->add_fieldset('Display options');
    
    $fieldset->add_field({
      'label'   => 'Width of image',
      'elements' => [{
        'type'    => 'dropdown',
        'name'    => 'cookie_width',
        'value'   => $ENV{'ENSEMBL_IMAGE_WIDTH'},
        'options' => [{
          'value'   => 'bestfit',
          'caption' => 'best fit'
          },
          map { { 'value' => $_, 'caption' => "$_ pixels" } } map $_*100, 5..20
        ],
      }],
    });
  }
  
  $self->tree->create_node('form_conf', { availability => 0, caption => 'Configure' }) unless $self->nav_tree;
}

# Set a key for user settings 	 
sub set { 	 
  my ($self, $key, $value, $force) = @_; 	 
  
  return unless $force || exists $self->{'_options'}{$key}; 	 
  return if $self->{'_options'}{$key}{'user'} eq $value;
  $self->altered = 1;
  $self->{'_options'}{$key}{'user'}  = $value;
}

sub get {
  my ($self, $key) = @_;
  
  return undef unless exists $self->{'_options'}{$key};
  
  my $type = exists $self->{'_options'}{$key}{'user'} ? 'user' : 'default';
  
  return ref $self->{'_options'}{$key}{$type} eq 'ARRAY' ? @{$self->{'_options'}{$key}{$type}} : $self->{'_options'}{$key}{$type};
}

sub is_option {
  my ($self, $key) = @_;
  return exists $self->{'_options'}{$key};
}

# Set the user settings from a hash of key value pairs
sub set_user_settings {
  my ($self, $diffs) = @_;
  
  if ($diffs) {
    $self->{'_options'}{$_}{'user'} = $diffs->{$_} for keys %$diffs;
  }
}

sub get_user_settings {
  my $self = shift;
  my $diffs = {};
  
  foreach my $key ($self->options) {
    $diffs->{$key} = $self->{'_options'}{$key}{'user'} if exists $self->{'_options'}{$key}{'user'} && $self->{'_options'}{$key}{'user'} ne $self->{'_options'}{$key}{'default'};
  }
  
  return $diffs;
}

1;
