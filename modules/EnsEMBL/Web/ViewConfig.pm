package EnsEMBL::Web::ViewConfig;

use strict;

use CGI::Cookie;
use Digest::MD5 qw(md5_hex);
use HTML::Entities qw(encode_entities);
use URI::Escape qw(uri_escape);

use EnsEMBL::Web::Form;
use EnsEMBL::Web::OrderedTree;

use base qw(EnsEMBL::Web::Root);

use constant {
  SELECT_ALL_FLAG => '_has_select_all',
};

sub new {
  my ($class, $type, $action, $hub) = @_;

  my $self = {
    hub                 => $hub,
    species             => $hub->species,
    species_defs        => $hub->species_defs,
    real                => 1,
    nav_tree            => 0,
    title               => undef,
    _options            => {},
    _image_config_names => {},
    default_config      => '_page',
    has_images          => 0,
    _form               => undef,
    _form_id            => sprintf('%s_%s_configuration', lc $type, lc $action),
    url                 => undef,
    tree                => new EnsEMBL::Web::OrderedTree,
    custom              => $ENV{'ENSEMBL_CUSTOM_PAGE'} ? $hub->session->custom_page_config($type) : [],
    type                => $type,
    action              => $action
  };
  
  bless $self, $class;
  
  $self->init;
  
  return $self;
}

sub hub            :lvalue { $_[0]->{'hub'};            }
sub default_config :lvalue { $_[0]->{'default_config'}; }
sub real           :lvalue { $_[0]->{'real'};           }
sub nav_tree       :lvalue { $_[0]->{'nav_tree'};       }
sub url            :lvalue { $_[0]->{'url'};            }
sub title          :lvalue { $_[0]->{'title'};          }
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
sub init          { return $_[0]->real = 0;             }

# Value indidates that the track can be configured for DAS (das) or not (nodas)
sub add_image_configs {
  my ($self, $image_config) = @_;
  
  foreach (keys %$image_config) {
    $self->{'_image_config_names'}->{$_} = $image_config->{$_};
    $self->has_images = 1 if $image_config->{$_} !~ /^V/
  }
}

sub has_image_config {
  my $self   = shift;
  my $config = shift;
  return exists $self->{'_image_config_names'}{$config};
}
sub image_config_names {
  my $self = shift;
  return keys %{$self->{'_image_config_names'} || {}};
}

sub image_configs {
  my $self = shift;
  return %{$self->{'_image_config_names'} || {}};
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
  return $self->{'_form'} || $self->has_images || $self->can('form');
}

sub get_form {
  my $self = shift;
  $self->{'_form'} ||= EnsEMBL::Web::Form->new({'id' => $self->{'_form_id'}, 'action' => $self->url, 'class' => 'configuration std'});
  return $self->{'_form'};
}

sub add_fieldset {
  my ($self, $legend, $class) = @_;
  
  (my $div_class = $legend) =~ s/ /_/g;
  
  my $fieldset = $self->get_form->add_fieldset($legend);
  $fieldset->set_attribute('class', $class) if $class;
  
  $self->tree->create_node(undef, { url => '#', availability => 1, caption => $legend, class => $div_class }) if $self->nav_tree;
    
  return $fieldset;
}

sub get_fieldset {
  my ($self, $i) = @_;

  my $fieldsets = $self->get_form->fieldsets;
  my $fieldset;
  
  if (int $i eq $i) {
    $fieldset = $fieldsets->[$i];
  }
  else {
    for (@$fieldsets) {
      $fieldset = $_ and last if $_->get_legend && $_->get_legend->inner_HTML eq $i
    }
  }
  
  return $fieldset;
}

sub add_form_element {
  my ($self, $element) = @_;

  if ($element->{'type'} eq 'CheckBox') {
    $element->{'selected'} = $self->get($element->{'name'}) eq $element->{'value'} ? 1 : 0 ;
  }
  elsif (not exists $element->{'value'}) {
    $element->{'value'} = $self->get($element->{'name'});
  }

  my $fieldset = $self->get_form->has_fieldset ? $self->get_form->fieldset : $self->add_fieldset('Display options');

  $self->get_form->add_element(%$element); ## TODO- modify it for the newer version of Form once all child classes are modified
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
sub update_from_url {
  my ($self, $r) = @_;
  my $hub     = $self->hub;
  my $session = $hub->session;
  my $input   = $hub->input;
  my $species = $hub->species;
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
  
  foreach my $name ($self->image_config_names) {
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
    
    $hub->get_imageconfig($name)->update_from_url(@values) if @values;
  }
  
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

sub build_form {
  my ($self, $object, $no_extra_bits) = @_;
  
  $self->form($object) if $self->can('form'); # can't use an empty form stub in the parent because has_form checks $self->can('form'). TODO: change has_form
  
  foreach my $fieldset (@{$self->get_form->fieldsets}) {

    ## Add select all checkboxes
    next if $fieldset->get_flag($self->SELECT_ALL_FLAG);
       
    my %element_types;
    my $elements = $fieldset->inputs;# returns all input, select and textarea nodes 
    
    for (@{$elements}) {
      $element_types{$_->node_name . $_->get_attribute('type')}++;
    }
    
    delete $element_types{$_} for qw(inputhidden inputsubmit);
    
    # If the fieldset is mostly checkboxes, provide a select/deselect all option
    if ($element_types{'inputcheckbox'} > 1 && [ sort { $element_types{$b} <=> $element_types{$a} } keys %element_types ]->[0] eq 'inputcheckbox') {
      my $reference_element = undef;
      
      for (@{$elements}) {
        $reference_element = $_ and last if $_->get_attribute('type') eq 'checkbox';
      }
      
      $reference_element = $reference_element->parent_node while defined $reference_element && ref($reference_element) !~ /::Form::Field$/; #get the wrapper of the element before using it as reference
      
      next unless defined $reference_element;
      
      my $select_all = $fieldset->add_field({
        type          => 'checkbox',
        name          => 'select_all',
        label         => 'Select/deselect all',
        value         => 'select_all',
        field_class   => 'select_all',
        selected      => 1
      });
      
      $fieldset->insert_before($select_all, $reference_element);
      $fieldset->set_flag($self->SELECT_ALL_FLAG);
    }
  }
  
  if (!$no_extra_bits && $self->has_images) {
    my $fieldset = $self->get_fieldset('Display options') || $self->add_fieldset('Display options');
    
    $fieldset->add_field({
      type    => 'DropDown',
      name    => 'cookie_width',
      value   => $ENV{'ENSEMBL_IMAGE_WIDTH'},
      label   => 'Width of image',
      values  => [
        { value => 'bestfit', caption => 'best fit' },
        map {{ value => $_, caption => "$_ pixels" }} map $_*100, 5..20
      ]
    });
  }
  
  for (@{$self->get_form->fieldsets}) {
    
    ## wrap the fieldset inside the div for JS to work properly
    my $wrapper_div = $_->dom->create_element('div');
    if (my $legend = $_->get_legend) {
      (my $div_class = $legend->inner_HTML) =~ s/ /_/g;
      $wrapper_div->set_attribute('class', $div_class);
    }
    $wrapper_div->append_child($_->parent_node->replace_child($wrapper_div, $_));
  }
  
  return if $no_extra_bits;
  
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
