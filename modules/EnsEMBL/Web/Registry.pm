package EnsEMBL::Web::Registry;

use EnsEMBL::Web::DBSQL::UserDBAdaptor;
use EnsEMBL::Web::DBSQL::UserAdaptor;
use EnsEMBL::Web::DBSQL::SessionAdaptor;
use EnsEMBL::Web::DBSQL::WebDBAdaptor;
use EnsEMBL::Web::DBSQL::NewsAdaptor;
use EnsEMBL::Web::DBSQL::HelpAdaptor;
use EnsEMBL::Web::Timer;
use EnsEMBL::Web::SpeciesDefs;
use EnsEMBL::Web::Object::Data::User;

use strict;
use Class::Std;

{
my %Timer_of     :ATTR( :set<timer>    :get<timer>    );
#-- Lazy loaded objects - these will have appropriate lazy loaders attached!
my %DBAdaptor_of      :ATTR;
my %WebAdaptor_of     :ATTR;
my %SpeciesDefs_of    :ATTR;
my %Das_sources_of    :ATTR;
my %User_of      :ATTR( :set<user>     :get<user>     );
my %Session_of   :ATTR( :set<session>  :get<session>  );
my %Script_of    :ATTR( :set<script>   :get<script>   );
my %Species_of   :ATTR( :set<species>  :get<species>  );
my %SessionAdaptor_of :ATTR( :get<sessionadaptor> );                    # To allow it to be reset
my %UserAdaptor_of    :ATTR( :get<useradaptor>    );                    # To allow it to be reset
my %NewsAdaptor_of    :ATTR( :get<newsadaptor>    );                    # To allow it to be reset
my %HelpAdaptor_of    :ATTR( :get<helpadaptor>    );                    # To allow it to be reset
my %UserDB_of :ATTR( :get<userdb>    );                    # To allow it to be reset
my %WebDB_of :ATTR( :get<webdb>    );                    # To allow it to be reset

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

  my $user = EnsEMBL::Web::Object::Data::User->new({ id => $self->get_user->id });
 
  foreach my $das (@{ $user->dases }) {
    $Das_sources_of{ ident $self }{$das->name} = $das->get_das_config;
    warn $Das_sources_of{ ident $self }{$das->name};
  }

  foreach (keys %$session_das) {
    $Das_sources_of{ ident $self }{$_} = $session_das->{$_};
  }
  
  return $Das_sources_of{ ident $self };
}

sub get_das_filtered_and_sorted {
  my( $self, $species ) = @_;
  my $T = $self->get_das;# "GET DAS...", warn $T;
  warn join "\n","KEYS", keys %{$T||{}},"VALUES",values %{$T||{}};
  my @T =
    map  { $_->[1] }
    sort { $a->[0] cmp $b->[0] }
    map  { [ $_->get_data->{'label'}, $_ ] }
    grep { !( exists $_->get_data->{'species'} && $_->get_data->{'species'} ne $species )}
    values %{ $T||{} };
  foreach my $thing (@T) {
   warn "THING: " . $thing->get_data->{name};
  }
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

sub dbAdaptor {
### a
### Lazy loaded DB adaptor....
  my $self = shift;
  return $DBAdaptor_of{ ident $self } ||=
    EnsEMBL::Web::DBSQL::UserDBAdaptor->new({ 'species_defs' => $self->species_defs });
}

sub websiteAdaptor {
### a
### Lazy loaded DB adaptor....
  my $self = shift;
  return $WebAdaptor_of{ ident $self } ||=
    EnsEMBL::Web::DBSQL::WebDBAdaptor->new({ 'species_defs' => $self->species_defs });
}

sub sessionAdaptor {
### a
### Lazy loaded Session adaptor....
  my $self = shift;
  $SessionAdaptor_of{ ident $self } ||= EnsEMBL::Web::DBSQL::SessionAdaptor->new({
    'db_adaptor'   => $self->dbAdaptor,
    'species_defs' => $self->species_defs
  });
}

sub userAdaptor {
### a
### Lazy loaded User adaptor....
  my $self = shift;
  return $UserAdaptor_of{ ident $self } ||=
    EnsEMBL::Web::DBSQL::UserAdaptor->new({
      'db_adaptor'   => $self->dbAdaptor,   ## Web user db adaptor
      'species_defs' => $self->species_defs ## Species defs..
    });
}

sub newsAdaptor {
### a
### Lazy loaded News adaptor....
  my $self = shift;
  return $NewsAdaptor_of{ ident $self } ||=
    EnsEMBL::Web::DBSQL::NewsAdaptor->new({
      'db_adaptor'   => $self->websiteAdaptor,   ## Website db adaptor
      'species_defs' => $self->species_defs ## Species defs..
    });
}

sub helpAdaptor {
### a
### Lazy loaded Help adaptor....
  my $self = shift;
  return $HelpAdaptor_of{ ident $self } ||=
    EnsEMBL::Web::DBSQL::HelpAdaptor->new({
      'db_adaptor'   => $self->websiteAdaptor,   ## Website db adaptor
      'species_defs' => $self->species_defs ## Species defs..
    });
}

sub userDB {
### x 
### Lazy loaded User DB....
### Deprecated. Use {{userAdaptor}} instead.
  my $self = shift;
  warn "xxxxxxxxxxxxx DEPRECATED xxxxxxxxxxxxxxxx";
  return $UserDB_of{ ident $self } ||= $self->userAdaptor;
}

sub webDB {
### a
### Lazy loaded Website DB....
  my $self = shift;
  return $WebDB_of{ ident $self } ||=
    EnsEMBL::Web::DBSQL::WebsiteAdaptor->new({
      'db_adaptor'   => $self->dbAdaptor,   ## Website db adaptor
      'species_defs' => $self->species_defs ## Species defs..
    });
}

sub initialize_user {
###
  my($self,$arg_ref)=@_;
#  $self->userAdaptor->set_request( $self->get_request );
  $self->set_user( $self->userAdaptor->get_user_from_cookie({
    'cookie'=> $arg_ref->{'cookie'},
    'r'     => $arg_ref->{'r'}
   }) );
}

sub initialize_session {
###
  my($self,$arg_ref)=@_;
  $self->set_species( $arg_ref->{'species'} ) if exists $arg_ref->{'species'};
  $self->set_script(  $arg_ref->{'script'}  ) if exists $arg_ref->{'script'};
  $self->set_session(
    $self->sessionAdaptor->get_session_from_cookie({
      'cookie'  => $arg_ref->{'cookie'},
      'r'       => $arg_ref->{'r'}
    })
  );
}

sub tidy_up {
  my $self = shift;
  $self->dbAdaptor->disconnect if $DBAdaptor_of{ ident $self };
}

}

1;


