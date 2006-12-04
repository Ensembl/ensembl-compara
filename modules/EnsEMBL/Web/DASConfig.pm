package EnsEMBL::Web::DASConfig;

use strict;
use Data::Dumper;
use Storable qw( nfreeze freeze thaw );

sub new {
  my $class   = shift;
  my $adaptor = shift;
  my $self = {
    '_db'       => $adaptor->{'user_db'},
    '_r'        => $adaptor->{'r'},
    '_data'     => {},
    '_altered'  => 0,
    '_deleted'  => 0
  };

  bless($self, $class);
  return $self;
}

sub get_name {
  my $self = shift;
  return $self->{'_data'}{'name'};
}

sub get_data {
  my $self = shift;
  return $self->{'_data'};
}

sub is_deleted {
  my $self = shift;
  return $self->{'_deleted'};
}

sub is_altered {
### a
### Set to one if the configuration has been updated...
  $_[0]->{'_altered'};
}

sub delete {
  my $self = shift;
  $self->{'_deleted'} = 1;
  $self->{'_data'}    = {};
  $self->{'_altered'} = 1;
}

sub load {
  my( $self, $data ) = @_;
  $self->{'_altered'} = 0;
  $self->{'_deleted'} = 0;
  $self->{'_data'}    = $data;
}

sub amend {
  my( $self, $data ) = @_;
  return if $self->{'_deleted'}; ## Can't amend a deleted source!
  $self->{'_altered'} = 1;
  $self->{'_data'}    = $data;
}

sub dump {
  my ($self) = @_;
  print STDERR Dumper($self);
}

1;
