package EnsEMBL::Web::Registry;

### NAME: EnsEMBL::Web::Registry
### Module to pass session information from Apache::Handlers to Magic

### STATUS: At risk
### If we can change over to using mod_perl "properly", we won't need
### to route URLs via a cgi script!

use strict;
use Data::Dumper;

use EnsEMBL::Web::Timer;
use EnsEMBL::Web::SpeciesDefs;
use EnsEMBL::Web::Data::User;
use EnsEMBL::Web::DASConfig;

sub new {
  my $class = shift;
  my $self = {
    'timer'         => undef,
    'dbcache'       => undef,
    'species_defs'  => undef,
    'user'          => undef,
    'ajax'          => undef,
    'session'       => undef,
    'script'        => undef,
    'species'       => undef,
    'type'          => undef,
    'action'        => undef,
  };
  bless $self, $class;
  return $self;
}

sub get_timer { return $_[0]->{'timer'}; }
sub set_timer { $_[0]->{'timer'} = $_[1]; }

sub get_dbcache { return $_[0]->{'dbcache'}; }
sub get_species_defs { return $_[0]->{'species_defs'}; }

sub get_user { return $_[0]->{'user'}; }
sub set_user { $_[0]->{'user'} = $_[1]; }

sub get_ajax { return $_[0]->{'ajax'}; }
sub set_ajax { $_[0]->{'ajax'} = $_[1]; }

sub get_session { return $_[0]->{'session'}; }
sub set_session { $_[0]->{'session'} = $_[1]; }

sub get_script { return $_[0]->{'script'}; }
sub set_script { $_[0]->{'script'} = $_[1]; }

sub get_species { return $_[0]->{'species'}; }
sub set_species { $_[0]->{'species'} = $_[1]; }

sub get_type { return $_[0]->{'type'}; }
sub set_type { $_[0]->{'type'} = $_[1]; }

sub get_action { return $_[0]->{'action'}; }
sub set_action { $_[0]->{'action'} = $_[1]; }

sub timer_push {
  my $self = shift;
  $self->timer->push( @_ );
}
sub timer {
  my $self = shift;
  return $self->{'timer'} ||= EnsEMBL::Web::Timer->new;
}

sub species_defs {
  ### a
  ### Lazy loaded SpeciesDefs object
  my $self = shift;
  return $self->{'species_defs'} ||= new EnsEMBL::Web::SpeciesDefs;
}

sub initialize_user {
  my ($self, $arg_ref) = @_;
  $arg_ref->{'cookie'}->retrieve($arg_ref->{'r'});

  my $id = $arg_ref->{'cookie'}->get_value;

  if ($id) {
      # try to log in with user id from cookie
      eval { $self->set_user(EnsEMBL::Web::Data::User->new($id)) };
      if ($@) {
	  # login failed (because the connection to the used db has gone away)
	  # so log the user out by clearing the cookie
	  $arg_ref->{'cookie'}->clear($arg_ref->{'r'});
	  $self->set_user(undef);
      }
  } else {
    $self->set_user(undef);
  }

##  TODO: decide if we still need 'defer' here, and implement if yes
##  defer => 'yes',
}



1;
