package EnsEMBL::Web::Registry;

use strict;
use Data::Dumper;

use EnsEMBL::Web::Timer;
use EnsEMBL::Web::SpeciesDefs;
use EnsEMBL::Web::Data::User;
use EnsEMBL::Web::Session;
use EnsEMBL::Web::DASConfig;

use Class::Std;

{
my %Timer_of     :ATTR( :set<timer>    :get<timer>    );
#-- Lazy loaded objects - these will have appropriate lazy loaders attached!
my %DBcache_of        :ATTR( :get<dbcache>  );
my %SpeciesDefs_of    :ATTR;
my %User_of           :ATTR( :set<user>     :get<user>     );
my %Ajax_of           :ATTR( :set<ajax>     :get<ajax>     );
my %Session_of        :ATTR( :set<session>  :get<session>  );
my %Script_of         :ATTR( :set<script>   :get<script>   );
my %Species_of        :ATTR( :set<species>  :get<species>  );
my %Type_of           :ATTR( :set<type>     :get<type>     );
my %Action_of         :ATTR( :set<action>   :get<action>   );

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
  
  my $spec_das = $self->species_defs->get_all_das( $species );
  my $sess_das = $self->get_session ->get_all_das( $species );
  my $user_das = $self->get_user ? $self->get_user->get_all_das( $species ) : {};
  
  # TODO: group data??
  
  my %merged = ( %{ $spec_das }, %{ $user_das }, %{ $sess_das } );
  return \%merged;
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
  return $Timer_of{ ident $self } ||= EnsEMBL::Web::Timer->new;
}

sub species_defs {
### a
### Lazy loaded SpeciesDefs object
  my $self = shift;
  return $SpeciesDefs_of{ ident $self } ||=
    EnsEMBL::Web::SpeciesDefs->new();
}

sub check_ajax {
### Checks whether ajax enabled or not
  my $self = shift;
  if (@_) {
    my $ajax = shift;
    $self->set_ajax( $ajax && $ajax->value eq 'enabled' ? 1 : 0 );
  } else {
    return $self->get_ajax;
  }
}

sub initialize_user {
###
  my ($self, $arg_ref) = @_;
  $arg_ref->{'cookie'}->retrieve($arg_ref->{'r'});

  my $id = $arg_ref->{'cookie'}->get_value;

  if ($id) {
    $self->set_user(EnsEMBL::Web::Data::User->new($id));
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

}

1;


