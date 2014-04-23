package EnsEMBL::Web::Lazy;

use strict;
use warnings;

#use Carp qw(cluck);

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
  #warn cluck("Looking for $AUTOLOAD: It's a ".ref($real)."!\n");
  bless $self,ref($real);
}

sub isa {
  my $self = shift;

  warn "ISA FORCE\n";
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

