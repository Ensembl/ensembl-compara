package EnsEMBL::Web::Registry;

use strict;
use Data::Dumper;

use EnsEMBL::Web::Timer;
use EnsEMBL::Web::SpeciesDefs;
use EnsEMBL::Web::Data::User;
use EnsEMBL::Web::Session;

use Class::Std;

{
my %Timer_of     :ATTR( :set<timer>    :get<timer>    );
#-- Lazy loaded objects - these will have appropriate lazy loaders attached!
my %DBcache_of        :ATTR( :get<dbcache>  );
my %SpeciesDefs_of    :ATTR;
my %Das_sources_of    :ATTR;
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
# Returns a hashref, indexed by name.
# An optional non-zero argument forces re-retrieval of das sources, otherwise
# these are cached.
sub get_all_das {
  my ( $self, $force ) = @_;
  
  # This is cached so return it unless "Force" is set to load in other stuff
  if ( !$force && scalar keys %{ $Das_sources_of{ ident $self } } ) {
    return $Das_sources_of{ ident $self };
  }
  
  my $spec_das = $self->species_defs->ENSEMBL_INTERNAL_DAS_SOURCES || {};
  my $user_das = $self->get_user    ->dases                        || {};
  my $sess_das = $self->get_session ->get_all_das                  || {};
  
  # Build config objects from the speciesdefs data
  for my $data ( values %{ $spec_das } ) {
    $data->{'display_label'} ||= $data->{'label'};
    my $das = EnsEMBL::Web::DASConfig->new_from_hashref( $data );
    $Das_sources_of{ ident $self }{ $das->logic_name } = $das;
  }
  
  # Override with user data
  for my $data ( values %{ $user_das } ) {
    my $das = EnsEMBL::Web::DASConfig->new_from_hashref( $data );
    grep { $_ eq $self->get_species } $das->species || next;
    $Das_sources_of{ ident $self }{ $das->logic_name } = $das;
  }
  
  # Override with session data
  for my $das ( values %{ $sess_das } ) {
    grep { $_ eq $self->get_species } $das->species || next;
    $Das_sources_of{ ident $self }{ $das->logic_name } = $das;
  }
  
  return $Das_sources_of{ ident $self };
}

# This method gets a single named DAS source for the current species.
# The source's configuration is an amalgam of species, user and session data.
sub get_das_by_logic_name {
  my ( $self, $name ) = @_;
  return $self->get_all_das->{ $name };
}

sub get_das_filtered_and_sorted {
  my ( $self ) = @_;
  
  my @sorted = sort {
    $a->display_label cmp $b->display_label
  } values %{ $self->get_all_das };

  return \@sorted;
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
      if ($ajax && $ajax->value ne 'disabled' && $ajax->value ne '') {
        $self->set_ajax(1);
      } else {
        $self->set_ajax(0);
      }
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
  $self->set_species( $arg_ref->{'species'} ) if exists $arg_ref->{'species'};
  $self->set_script(  $arg_ref->{'script'}  ) if exists $arg_ref->{'script'};
  $self->set_action(  $arg_ref->{'action'}  ) if exists $arg_ref->{'action'};
  $self->set_type(    $arg_ref->{'type'}    ) if exists $arg_ref->{'type'};
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


