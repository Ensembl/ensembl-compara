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
use EnsEMBL::Web::Session;
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

# This method gets all configured DAS sources for the current species.
# Source configurations are retrieved first from SpeciesDefs, then additions and
# modifications are added from the User and Session.
# Returns a hashref, indexed by logic_name.
sub get_all_das {
  my $self    = shift;
  my $species = shift || $ENV{'ENSEMBL_SPECIES'};
  
  if ( $species eq 'common' ) {
    $species = '';
  }
  
  my @spec_das = $self->species_defs->get_all_das( $species );
  my @sess_das = $self->get_session ->get_all_das( $species );
  my @user_das = $self->get_user ? $self->get_user->get_all_das( $species ) : ({},{});
  
  # TODO: group data??
  
  # First hash is keyed by logic_name, second is keyed by full_url
  my %by_name = ( %{ $spec_das[0] }, %{ $user_das[0] }, %{ $sess_das[0] } );
  my %by_url  = ( %{ $spec_das[1] || {}}, %{ $user_das[1] || {} }, %{ $sess_das[1] || {}} );
  return wantarray ? ( \%by_name, \%by_url ) : \%by_name;
}

# This method gets a single named DAS source for the current species.
# The source's configuration is an amalgam of species, user and session data.
sub get_das_by_logic_name {
  my ( $self, $name ) = @_;
  return $self->get_all_das->{ $name };
}

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
  return $self->{'species_defs'} ||=
    EnsEMBL::Web::SpeciesDefs->new();
}

sub initialize_user {
###
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

sub initialize_session {
###
  my($self,$arg_ref)=@_;
  $self->set_species( $arg_ref->{'species'} );# if exists $arg_ref->{'species'};
  $self->set_script(  $arg_ref->{'script'}  );# if exists $arg_ref->{'script'};
  $self->set_action(  $arg_ref->{'action'}  );# if exists $arg_ref->{'action'};
  $self->set_type(    $arg_ref->{'type'}    );# if exists $arg_ref->{'type'};
  $arg_ref->{'cookie'}->retrieve($arg_ref->{'r'});

  $self->set_session(
    EnsEMBL::Web::Session->new({
      'adaptor'      => $self,
      'cookie'       => $arg_ref->{'cookie'},
      'session_id'   => $arg_ref->{'cookie'}->get_value,
      'species_defs' => $self->species_defs,
      'species'      => $arg_ref->{'species'}
    })
  );
}

1;


