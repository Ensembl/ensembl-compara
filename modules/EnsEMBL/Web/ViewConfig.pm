package EnsEMBL::Web::ViewConfig;

use strict;
use Data::Dumper;
use EnsEMBL::Web::Form;

sub new {
  my($class,$type,$action,$adaptor) = @_;

  my $self = {
    '_db'                 => $adaptor->get_adaptor,
    '_r'                  => $adaptor->get_request || undef,
    'type'                => $type,
    'real'                => 0,
    'action'              => $action,
    'title'               => undef,
    '_classes'            => [],
    '_options'            => {},
    '_image_config_names' => {},
    '_form'               => undef,
    '_url'                => undef,
    'no_load'             => undef
  };

  bless($self, $class);
  return $self;
}

sub real :lvalue {
  $_[0]->{'real'};
}

sub url :lvalue {
### a
  $_[0]->{'_url'};
}
sub title :lvalue {
### a
  $_[0]->{'title'};
}
sub storable :lvalue {
### a
### Set whether this ViewConfig is changeable by the User, and hence needs to
### access the database to set storable do $view_config->storable = 1; in SC code...
  $_[0]->{'storable'};
}

sub altered :lvalue {
### a
### Set to one if the configuration has been updated...
  $_[0]->{'altered'};
}

sub add_image_configs { ## Value indidates that the track can be configured for DAS (das) or not (nodas)
  my( $self, $hash_ref ) = @_;
  foreach( keys %$hash_ref ) {
    $self->{_image_config_names}{$_} = $hash_ref->{$_};
    $self->has_images(1);
  }
}

sub has_image_config {
  my $self = shift;
  my $config = shift;
  return exists $self->{_image_config_names}{$config};
}
sub has_image_configs {
  my $self = shift;
  return keys %{$self->{_image_config_names}||{}};
}

sub image_configs {
  my $self = shift;
  return %{$self->{_image_config_names}||{}};
}

sub _set_defaults {
  my $self = shift;
  my %defs = (@_, map( { ("format_$_", 'off')} qw(svg postscript pdf) ) );
  foreach my $key (keys %defs) {
    $self->{_options}{$key}{'default'} = $defs{$key};
  }
}

sub _clear_defaults {
  my $self = shift;
  $self->{_options} = {};
}

sub _remove_defaults {
### Clears the listed default values...
  my $self = shift;
  foreach my $key (@_) {
    delete $self->{_options}{$key};
  }
}

sub options { 
  my $self = shift;
  return keys %{$self->{'_options'}};
}

sub has_form {
  my $self = shift;
  return $self->{_form};
}

sub get_form {
  my $self = shift;
  $self->{_form}||=EnsEMBL::Web::Form->new( 'configuration', $self->url,'post' );
  return $self->{_form};
}

sub add_fieldset {
  my( $self, $legend ) = @_;
  my $fieldset = $self->get_form->add_fieldset('form'=>'configuration');
  $fieldset->legend($legend);
}

sub add_form_element {
  my($self,$hashref) = @_;
  my @extra;
  my $value = $self->get($hashref->{'name'});
  if( $hashref->{'type'} eq 'CheckBox' ) {
    push @extra, 'checked' => $value eq $hashref->{'value'} ? 1 : 0;
  } elsif( !exists $hashref->{'value'} ) {
    push @extra, 'value' => $value;
  }
  $self->get_form->add_element(%$hashref,@extra);
}

sub update_config_from_parameter {
### Update the configuration from a pipe separated string...
  my( $self, $string ) = @_;
  my @array = split /\|/, $string;
  return unless @array;
  foreach( @array ) {
    next unless $_;
    my( $key, $value ) = split ':';
    $self->set( $key, $value );
  }
}

sub update_from_input {
### Loop through the parameters and update the config based on the parameters passed!
  my( $self, $input ) = @_;
  my $flag = 0;
  if( $input->param('reset') ) {
    return $self->reset;
  }
  foreach my $key ( $self->options ) {
    if( defined $input->param($key) && $input->param( $key ) ne $self->{'_options'}{$key}{'user'} ) {
      $flag = 1;
      my @values = $input->param( $key );
      if( scalar(@values) > 1 ) {
        $self->set( $key, \@values );
      } else {
        $self->set( $key, $input->param( $key ) );
      }
    }
  }
  if( $flag ) {
    $self->altered = 1;
  }
  return;
}

sub delete {
### Delete a key from the user settings
  my($self, $key ) = @_;
  return unless exists $self->{'_options'}{$key}{'user'};
  $self->altered = 1;
  delete $self->{'_options'}{$key}{'user'};
  return;
}

sub reset {
### Delete all keys from user settings
  my ($self) = @_;
  foreach my $key ( $self->options ) {
    next unless exists $self->{'_options'}{$key}{'user'};
    $self->altered = 1;
    delete $self->{'_options'}{$key}{'user'};
  }
  return;
}

sub push_class {
  my($self, $class) =@_;
  push @{$self->{'_classes'}}, $class;
}

sub has_images {
  my $self = shift;
  $self->{_has_images} = shift if @_;
  return $self->{_has_images};
}

sub form {
  my( $self, $object ) = @_;
  foreach my $classname (@{$self->{'_classes'}}) {
    my $method = $classname.'::form';
    eval { no strict 'refs'; &$method( $self, $object ); };
  }
  if( $self->has_images ||
       $ENV{'ENSEMBL_AJAX_VALUE'} =~ /^(en|dis)abled$/ && $self->has_form ) {
    $self->add_fieldset( 'General view configurations' );
    if( $self->has_images ) {
      $self->add_form_element({
        'type'     => 'DropDown', 'select' => 'select',
        'required' => 'yes',      'name'   => 'cookie_width',
        'values'   => [
          { 'value' => 'bestfit', 'name' => 'best fit' },
          map { { 'value' => $_, 'name' => "$_ pixels" } } map {$_*100} (5..20)
        ],
        'value'    => $ENV{'ENSEMBL_IMAGE_WIDTH'},
        'label'    => "Width of image",
      });
    }
    if( $ENV{'ENSEMBL_AJAX_VALUE'} =~ /^(en|dis)abled$/ ) {
      $self->add_form_element({
        'type'     => 'DropDown', 'select' => 'select',
        'required' => 'yes',      'name'   => 'cookie_ajax',
        'values'   => [
          { 'value' => 'enabled',  'name' => 'Enabled' },
          { 'value' => 'disabled', 'name' => 'Disabled' },
        ],
        'value'    => $ENV{'ENSEMBL_AJAX_VALUE'},
        'label'    => "Enable/disable use of AJAX in rendering"
      });
    }
  }
  $self->add_form_element({
   'type' => 'Submit', 'value' => 'Update configuration'
  }) if $self->has_form;
}

sub set {
### Set a key for user settings
  my( $self, $key, $value, $force ) = @_;
#warn caller(1);
#warn "SETTING: $self - $key $value $force";
  return unless $force || exists $self->{'_options'}{$key};
  return if $self->{'_options'}{$key}{'user'}  eq $value;
#warn "setting $key to $value";
  $self->altered = 1;
  $self->{'_options'}{$key}{'user'}  = $value;
}



#sub set {
#  my( $self, $key, $value, $force ) = @_;
#  return unless $force || exists $self->{'_options'}{$key};
#  $self->{'_options'}{$key}{'user'}  = $value;
#}

sub get {
  my( $self, $key ) = @_;
  return undef unless exists $self->{'_options'}{$key};
  if( exists ($self->{'_options'}{$key}{'user'}) ) {
    if( ref($self->{'_options'}{$key}{'user'}) eq 'ARRAY' ) {
      return @{$self->{'_options'}->{$key}->{'user'}};
    }
    return $self->{'_options'}{$key}{'user'};
  }
  if( ref($self->{'_options'}{$key}{'default'}) eq 'ARRAY' ) {
    return @{$self->{'_options'}{$key}{'default'}};
  }
  return $self->{'_options'}{$key}{'default'};
}

sub is_option {
  my( $self, $key ) = @_;
  return exists $self->{'_options'}{$key};
}

sub set_user_settings {
### Set the user settings from a hash of key value pairs
  my( $self, $diffs ) = @_;
  if( $diffs ) {
    foreach my $key ( keys %$diffs ) {
      $self->{'_options'}{$key}{'user'} = $diffs->{$key};
    }
  }
}

sub get_user_settings {
  my $self = shift;
  my $diffs = {};
  foreach my $key ( $self->options ) {
    $diffs->{$key} = $self->{'_options'}{$key}{'user'} if exists($self->{'_options'}{$key}{'user'}) && $self->{'_options'}{$key}{'user'} ne $self->{'_options'}{$key}{'default'};
  }
  return $diffs;
}

sub load {
  my ($self) = @_;
  warn "ViewConfig load - Deprecated call - now written by session";
  return;
}

sub save {
  my ($self) = @_;
  warn "ViewConfig load - Deprecated call - now written by session";
  return;
}

sub dump {
  my ($self) = @_;
  print STDERR Dumper($self);
}

1;
