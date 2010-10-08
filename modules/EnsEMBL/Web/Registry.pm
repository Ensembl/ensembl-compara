# $Id$

package EnsEMBL::Web::Registry;

use strict;

use EnsEMBL::Web::Data::User;
use EnsEMBL::Web::SpeciesDefs;
use EnsEMBL::Web::Timer;

sub new {
  my $class = shift;
  
  my $self = {
    timer         => undef,
    species_defs  => undef,
    user          => undef,
  };
  
  bless $self, $class;
  return $self;
}

sub species_defs { return $_[0]{'species_defs'} ||= new EnsEMBL::Web::SpeciesDefs; }
sub timer        { return $_[0]{'timer'}        ||= new EnsEMBL::Web::Timer;       }

sub timer_push   { shift->timer->push(@_); }

sub user :lvalue { $_[0]{'user'};  }

sub initialize_user {
  my ($self, $cookie, $r) = @_;
  
  $cookie->retrieve($r);

  my $id = $cookie->get_value;

  if ($id) {
    my $user;
    
    # try to log in with user id from cookie
    eval { 
      $self->user = new EnsEMBL::Web::Data::User($id);
    };
      
    if ($@) {
      # login failed (because the connection to the used db has gone away)
      # so log the user out by clearing the cookie
      $cookie->clear($r);
      $self->user = undef;
    }
  }
}

1;
