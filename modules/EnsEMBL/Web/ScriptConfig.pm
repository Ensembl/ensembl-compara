package EnsEMBL::Web::ScriptConfig;

use strict;
use Data::Dumper;
use Storable qw( nfreeze freeze thaw );

sub update_config_from_parameter {
  my( $self, $string ) = @_;
  my @array = split /\|/, $string;
  shift @array;
  return unless @array;
  foreach( @array ) {
    my( $key, $value ) = split ':';
    $self->set( $key, $value );
  }
  $self->save( );
}

sub new {
  my $class   = shift;
  my $type    = shift;
  my $adaptor = shift;
  my $self = {
    '_db'       => $adaptor->{'user_db'},
    '_r'        => $adaptor->{'r'},
    'type'      => $type,
    '_options'  => {},
    'no_load'   => $adaptor->{'no_load'}
  };

  bless($self, $class);
  return $self;
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

sub options { 
  my $self = shift;
  return keys %{$self->{'_options'}};
}

sub update_from_input {
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
    $self->save( );
  }
  return;
}

sub set {
  my( $self, $key, $value, $force ) = @_;
  return unless $force || exists $self->{'_options'}{$key};
  $self->{'_options'}{$key}{'user'}  = $value;
}

sub get {
  my( $self, $key ) = @_;
  return undef unless exists $self->{'_options'}{$key};
  if( exists ($self->{'_options'}{$key}{'user'}) ) {
    if( ref($self->{'_options'}{$key}{'user'}) eq 'ARRAYREF' ) {
      return @{$self->{'_options'}->{$key}->{'user'}};
    }
    return $self->{'_options'}{$key}{'user'};
  }
  return $self->{'_options'}{$key}{'default'};
}

sub is_option {
  my( $self, $key ) = @_;
  return exists $self->{'_options'}{$key};
}

sub load {
  my ($self) = @_;
  return unless $self->{'_db'};
  my $TEMP = $self->{'_db'}->getConfigByName( $ENV{'ENSEMBL_FIRSTSESSION'}, 'script::'.$self->{'type'} );
  my $diffs = {};
  eval { $diffs = Storable::thaw( $TEMP ) if $TEMP; };
  foreach my $key ( keys %$diffs ) {
    $self->{'_options'}{$key}{'user'} = $diffs->{$key};
  }
}

sub save {
  my ($self) = @_;
  return unless $self->{'_db'};
  my $diffs = {};
  foreach my $key ( $self->options ) {
    $diffs->{$key} = $self->{'_options'}{$key}{'user'} if exists($self->{'_options'}{$key}{'user'}) && $self->{'_options'}{$key}{'user'} ne $self->{'_options'}{$key}{'default'};
  }
  $self->{'_db'}->setConfigByName( $self->{'_r'}, $ENV{'ENSEMBL_FIRSTSESSION'}, 'script::'.$self->{'type'}, &Storable::nfreeze($diffs) );
  return;
}

sub reset {
  my ($self) = @_;
  $self->{'_db'}->clearConfigByName( $ENV{'ENSEMBL_FIRSTSESSION'}, 'script::'.$self->{'type'} );
  foreach my $key ( $self->options ) {
    delete $self->{'_options'}{$key}{'user'};
  }
  return;
}

sub delete {
  my ($self,$key) = @_;
  delete $self->{'_options'}{$key}{'user'};
}

sub dump {
  my ($self) = @_;
  print STDERR Dumper($self);
}

1;
