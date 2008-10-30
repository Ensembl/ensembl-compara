package EnsEMBL::Web::Document::Renderer;

use strict;
use Apache2::RequestUtil;

sub new {
  my $class = shift;

  my $self = {
    r     => undef,
    cache => undef,
    @_,
  };

  bless $self, $class;
  $self->r ||= Apache2::RequestUtil->can('request') ? Apache2::RequestUtil->request : undef;
  
  return $self;
}

sub r       :lvalue { $_[0]->{r} }
sub cache   :lvalue { $_[0]->{cache} }
sub session :lvalue { $_[0]->{session} }

sub valid   {1}
sub fh      {}
sub printf  {}
sub print   {}
sub close   {}
sub content {}
sub value   { shift->content }

1;