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
  my ($class, $type, $action, $adaptor) = @_;

  my $self = {
    _species            => $adaptor->get_species,
    _species_defs       => $adaptor->get_species_defs,
    real                => 0,
    external_data       => 0,
    nav_tree            => 0,
    title               => undef,
    _classes            => [],
    _options            => {},
    _image_config_names => {},
    _default_config     => '_page',
    _can_upload         => 0,
    _has_images         => 0,
    _form               => undef,
    _form_id            => sprintf('%s_%s_configuration', lc $type, lc $action),
    _url                => undef,
    _tree               => new EnsEMBL::Web::OrderedTree,
    _custom             => $ENV{'ENSEMBL_CUSTOM_PAGE'} ? $adaptor->custom_page_config($type) : [],
    _type               => $type
  };
  
  bless $self, $class;
  return $self;
}

sub default_config :lvalue { $_[0]->{'_default_config'}; }
sub real           :lvalue { $_[0]->{'real'}; }
sub external_data  :lvalue { $_[0]->{'external_data'}; }
sub nav_tree       :lvalue { $_[0]->{'nav_tree'}; }
sub url            :lvalue { $_[0]->{'_url'}; }
sub title          :lvalue { $_[0]->{'title'}; }
sub can_upload     :lvalue { $_[0]->{'_can_upload'} }
sub has_images     :lvalue { $_[0]->{'_has_images'}; }
sub altered        :lvalue { $_[0]->{'altered'}; }  # Set to one if the configuration has been updated
sub storable       :lvalue { $_[0]->{'storable'}; } # Set whether this ViewConfig is changeable by the User, and hence needs to access the database to set storable do $view_config->storable = 1; in SC code
sub custom         :lvalue { $_[0]->{'_custom'}; }
sub species                { return $_[0]->{'_species'}; }
sub species_defs           { return $_[0]->{'_species_defs'}; }
sub is_custom              { return $ENV{'ENSEMBL_CUSTOM_PAGE'}; }
sub type                   { return $_[0]->{'_type'}; }
sub tree                   { return $_[0]->{'_tree'}; }

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
  my $self = shift;
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
  return $self->{'_form'};
}

sub get_form {
  my $self = shift;
  $self->{'_form'} ||= EnsEMBL::Web::Form->new($self->{'_form_id'}, $self->url, 'post', 'configuration std check');
  return $self->{'_form'};
}

sub add_fieldset {
  my ($self, $legend, $layout) = @_;
  
  (my $class = $legend) =~ s/ /_/g;
  my $fieldset = $self->get_form->add_fieldset('form' => $self->{'_form_id'}, 'layout' => $layout);
  $fieldset->legend($legend);
  $fieldset->class($class);
  
  $self->tree->create_node(undef, { url => '#', availability => 1, caption => $legend, class => $class }) if $self->nav_tree;
  
  return $fieldset;
}

sub get_fieldset {
  my ($self, $i) = @_;
  
  my $fieldsets = $self->get_form->{'_fieldsets'};
  my $fieldset;
  
  if (int $i eq $i) {
    $fieldset = $fieldsets->[$i]; # $i is an array index
  } else {
    ($fieldset) = grep $_->legend eq $i, @$fieldsets; # $i is a legend
  }
  
  return $fieldset;
}

sub add_form_element {
  my ($self, $element) = @_;
  
  my @extra;
  my $value = $self->get($element->{'name'});
  
  if ($element->{'type'} =~ /CheckBox/) {
    push @extra, 'checked' => $value eq $element->{'value'} ? 1 : 0;
  } elsif (!exists $element->{'value'}) {
    push @extra, 'value' => $value;
  }
  
  my $new_fieldset = $self->get_form->add_element(%$element, @extra);
  
  if ($new_fieldset) {
    $new_fieldset->legend('Display options');
    $self->tree->create_node(undef, { url => '#', availability => 1, caption => 'Display options', class => 'generic' }) if $self->nav_tree;
  }
}

# Update the configuration from a pipe separated string
sub update_config_from_parameter {
  my ($self, $string) = @_;
  my @array = split /\|/, $string;
  
  return unless @array;
  
  foreach (@array) {
    next unless $_;
    my ($key, $value) = split ':';
    $self->set($key, $value);
  }
}

# Loop through the parameters and update the config based on the parameters passed
sub update_from_input {
  my ($self, $input) = @_;
  my $flag = 0;
  
  return $self->reset if $input->param('reset');
  
  foreach my $key ($self->options) {
    if (defined $input->param($key) && $input->param($key) ne $self->{'_options'}{$key}{'user'}) {
      $flag = 1;
      my @values = $input->param($key);
      
      if (scalar @values > 1) {
        $self->set($key, \@values);
      } else {
        $self->set($key, $input->param($key));
      }
    }
  }
  
  $self->altered = 1 if $flag;
}

# Loop through the parameters and update the config based on the parameters passed
sub update_from_config_strings {
  my ($self, $session, $r) = @_;
  my $input       = $session->input;
  my $updated     = 0;
  my $not_updated = 0;
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
      my $ic = $session->getImageConfig($name, $name);
      next unless $ic;
      
      foreach my $v (@values) {
        my ($key, $render) = split /=/, $v, 2;
        
        if ($key =~ /^(\w+)[\.:](.*)$/) {
          my ($type, $p) = ($1, $2);
          
          if ($type eq 'url') {
            $p = uri_unescape($p);
            
            # We have to create a URL upload entry in the session
            my $code = md5_hex("$ENV{'ENSEMBL_SPECIES'}:$p");
            my $n    =  $p =~ /\/([^\/]+)\/*$/ ? $1 : 'un-named';
            
            $session->set_data(
              type    => 'url',
              url     => $p,
              species => $ENV{'ENSEMBL_SPECIES'},
              code    => $code, 
              name    => $n
            );
            
            $session->add_data(
              type     => 'message',
              function => '_info',
              code     => 'url_data:' . md5_hex($p),
              message  => sprintf('Data has been attached to your display from the following URL: %s', encode_entities($p))
            );
            
            # We then have to create a node in the user_config
            $ic->_add_flat_file_track(undef, 'url', "url_$code", $n, 
              sprintf('Data retrieved from an external webserver. This data is attached to the %s, and comes from URL: %s', encode_entities($n), encode_entities($p)),
              'url' => $p
            );
            
            my $nd = $ic->get_node("url_$code");
            
            if ($nd) {
              my %valid_renderers = @{$nd->data->{'renderers'}};
              $updated += $nd->set_user('display', $render) if $valid_renderers{$render}; # Then we have to set the renderer
            }
          } elsif ($type eq 'das') {
            $p = uri_unescape($p);
            
            if (my $error = $session->add_das_from_string($p, { 'ENSEMBL_IMAGE' => $name }, {'display' => $render })) {
              $session->add_data(
                type     => 'message',
                function => '_warning',
                code     => 'das:' . md5_hex($p),
                message  => sprintf('You attempted to attach a DAS source with DSN: %s, unfortunately we were unable to attach this source (%s)', encode_entities($p), encode_entities($error))
              );
              
              warn $error;
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
          my $nd = $ic->get_node($key);          
          
          next unless $nd;
          
          my %valid_renderers = @{$nd->data->{'renderers'}};
          
          # Only allow track enabling/disabling. Don't allow enabled tracks' renders to be changed.
          if ($valid_renderers{$render} && ($render eq 'off' || $nd->get('display') eq 'off')) {
            $updated += $nd->set_user('display', $render);
          } else {
            $not_updated++;
          }
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

  return $params_removed ? join '?', [split /\?/, $ENV{'REQUEST_URI'}]->[0], $input->query_string : undef;
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
  
  foreach my $fieldset (@{$self->get_form->{'_fieldsets'}}) {
    next if $fieldset->{'select_all'};
    
    my $checkboxes;
    $checkboxes++ for grep { $_->type eq 'CheckBox' } @{$fieldset->elements};
    
    # If the fieldset has only checkboxes, provide a select/deselect all option
    if ($checkboxes > 1) {
      my $position = 0;
      
      foreach (@{$fieldset->elements}) {
        last if $_->type eq 'CheckBox';
        $position++;
      }
      
      $fieldset->add_element(
        type    => 'CheckBox',
        name    => 'select_all',
        label   => 'Select/deselect all',
        value   => 'select_all',
        classes => [ 'select_all' ]
      );
      
      splice @{$fieldset->{'_element_order'}}, $position, 0, pop @{$fieldset->{'_element_order'}}; # Make it the first checkbox
      
      $fieldset->{'select_all'} = 1;
    }
  }
  
  return if $no_extra_bits;
  
  if ($self->has_images) {
    my $fieldset = $self->get_fieldset('Display options') || $self->add_fieldset('Display options');
    
    $fieldset->add_element(
      type   => 'DropDown',
      select => 'select',
      name   => 'cookie_width',
      value  => $ENV{'ENSEMBL_IMAGE_WIDTH'},
      label  => 'Width of image',
      values => [
        { value => 'bestfit', name => 'best fit' },
        map {{ value => $_, name => "$_ pixels" }} map $_*100, 5..20
      ]
    );
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
