package EnsEMBL::Web::ViewConfig;

use strict;
use Data::Dumper;
use Storable qw( nfreeze freeze thaw );

sub new {
  my $class   = shift;
  my $type    = shift;
  my $adaptor = shift;
  my $self = {
    '_db'       => $adaptor->get_adaptor,
    '_r'        => $adaptor->get_request || undef,
    'type'      => $type,
    '_options'  => {},
    '_user_config_names' => {},
    'no_load'   => undef
  };

  bless($self, $class);
  return $self;
}

sub storable :lvalue {
### a
### Set whether this ScriptConfig is changeable by the User, and hence needs to
### access the database to set storable do $script_config->storable = 1; in SC code...
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
    $self->{_user_config_names}{$_} = $hash_ref->{$_};
  }
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
  foreach my $key ( $self->options ) {
    if( defined $input->param($key) && $input->param( $key ) ne $self->{'_options'}{$key}{'user'} ) {
      $flag = 1;
      my @values = $input->param( $key );
      if( scalar(@values) > 1 ) {
        $self->set( $key, \@values );
      } else {
        $self->set( $key, $input->param( $key ), $key=~ /^panel_/ );
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
  #warn "Loading from ScriptConfig";
warn "ScriptConfig load - Deprecated call - now written by session";
  return;
  return unless $self->{'_db'};
#warn "LOAD SC";
  my $TEMP = $self->{'_db'}->getConfigByName( $ENV{'ENSEMBL_FIRSTSESSION'}, 'script::'.$self->{'type'} );
  my $diffs = {};
  eval { $diffs = Storable::thaw( $TEMP ) if $TEMP; };
  foreach my $key ( keys %$diffs ) {
    $self->{'_options'}{$key}{'user'} = $diffs->{$key};
  }
}

sub save {
  my ($self) = @_;
  #warn "Saving from ScriptConfig";
  warn "ScriptConfig load - Deprecated call - now written by session";
  return;
  return unless $self->{'_db'};
  my $diffs = {};
  foreach my $key ( $self->options ) {
    $diffs->{$key} = $self->{'_options'}{$key}{'user'} if exists($self->{'_options'}{$key}{'user'}) && $self->{'_options'}{$key}{'user'} ne $self->{'_options'}{$key}{'default'};
  }
  #warn "Diffs: " . $diffs;
  $self->{'_db'}->setConfigByName( $self->{'_r'}, $ENV{'ENSEMBL_FIRSTSESSION'}, 'script::'.$self->{'type'}, &Storable::nfreeze($diffs) );
  return;
}

sub dump {
  my ($self) = @_;
  print STDERR Dumper($self);
}

1;
