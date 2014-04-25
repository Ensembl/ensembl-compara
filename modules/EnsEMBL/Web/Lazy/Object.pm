package EnsEMBL::Web::Lazy::Object;

use strict;
use warnings;

sub new {
  my ($proto,$reify) = @_;

  my $class = ref($proto) || $proto;
  my $self = {
    reify => $reify,
  };
  bless $self,$class;
  return $self;
}

sub __force {
  my ($self) = @_;

  my $real = $self->{'reify'}->();
  %$self = %$real;
  bless $self,ref($real);
}

sub isa {
  my $self = shift;

  $self->__force;
  return $self->isa(@_);
}

our $AUTOLOAD;
sub AUTOLOAD {
  my $self = shift;
  my $module = $AUTOLOAD;
  $module =~ /^(.*)::([^:]+)$/;
  my ($pkg,$sub) = ($1,$2);
  $self->__force;
  return $self->$sub(@_);
}

1;

