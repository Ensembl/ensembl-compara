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

our $AUTOLOAD;
sub AUTOLOAD {
  my $self = shift;
  my $module = $AUTOLOAD;
  $module =~ /^(.*)::([^:]+)$/;
  my ($pkg,$sub) = ($1,$2);
  my $real = $self->{'reify'}->();
  %$self = %$real;
  #warn cluck("Looking for $AUTOLOAD: It's a ".ref($real)."!\n");
  bless $self,ref($real);
  return $self->$sub(@_);
}

1;

