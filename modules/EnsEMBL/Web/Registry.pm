package EnsEMBL::Web::Registry;

use EnsEMBL::Web::Timer;
use EnsEMBL::Web::SpeciesDefs;
use EnsEMBL::Web::Data::User;
use EnsEMBL::Web::Session;

use strict;
use Class::Std;

{
my %Timer_of     :ATTR( :set<timer>    :get<timer>    );
#-- Lazy loaded objects - these will have appropriate lazy loaders attached!
my %DBcache_of        :ATTR( :get<dbcache>  );
my %SpeciesDefs_of    :ATTR;
my %Das_sources_of    :ATTR;
my %User_of           :ATTR( :set<user>     :get<user>     );
my %Session_of        :ATTR( :set<session>  :get<session>  );
my %Script_of         :ATTR( :set<script>   :get<script>   );
my %Species_of        :ATTR( :set<species>  :get<species>  );

## DAS functionality - most of this is moved from EnsEMBL::Web::ExternalDAS which
## will be deprecated - and now stores each source in the database separately
## currently only works with External DAS sources - not Internally configured DAS
## sources, making these changes should make the re-work to use registry more
## useful - as we can add an "add_das_source_from_registry" call as well as
## the add_das_source_from_URL and add_das_source_from_hashref

sub get_das {
### DAS
### Retrieve all externally configured DAS sources
### An optional "true" value forces the re-retrival of das sources, otherwise
### retrieved from the session hash...
  my( $self, $force ) = @_;
## This is cached so return it unless "Force" is set to load in other stuff
  return $Das_sources_of{ ident $self } if keys %{ $Das_sources_of{ ident $self } } && ! $force;
## No session so cannot have anything configured!
  my $session_das = $self->get_session->get_das;

  if (my $user = $self->get_user) {
    foreach my $das ($user->dases) {
      $Das_sources_of{ ident $self }{$das->name} = $das->get_das_config;
      #warn $Das_sources_of{ ident $self }{$das->name};
    }
  }

  foreach (keys %$session_das) {
    $Das_sources_of{ ident $self }{$_} = $session_das->{$_};
  }
  
  return $Das_sources_of{ ident $self };
}

sub get_das_filtered_and_sorted {
  my( $self, $species ) = @_;
  my $T = $self->get_das;# "GET DAS...", warn $T;
#  warn join "\n","KEYS", keys %{$T||{}},"VALUES",map { join '; ',keys %{$_->get_data||{}} } values %{$T||{}};
  my @T =
    map  { $_->[1] }
    sort { $a->[0] cmp $b->[0] }
    map  { [ $_->get_data->{'label'}, $_ ] }
    grep { !( exists $_->get_data->{'species'} && $_->get_data->{'species'} ne $species )}
    values %{ $T||{} };
#  foreach my $thing (@T) {
#   warn "THING: " . $thing->get_data->{name};
#  }
  return \@T;
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


