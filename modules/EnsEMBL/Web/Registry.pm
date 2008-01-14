package EnsEMBL::Web::Registry;

use EnsEMBL::Web::DBSQL::UserDBAdaptor;
use EnsEMBL::Web::DBSQL::SessionAdaptor;
use EnsEMBL::Web::DBSQL::WebDBAdaptor;
use EnsEMBL::Web::DBSQL::NewsAdaptor;
use EnsEMBL::Web::Timer;
use EnsEMBL::Web::SpeciesDefs;
use EnsEMBL::Web::Data::User;
#use Cache::Memcached;
#use EnsEMBL::Web::DBCache;
#use EnsEMBL::Web::FakeMemcached;

use strict;
use Class::Std;

{
my %Timer_of     :ATTR( :set<timer>    :get<timer>    );
#-- Lazy loaded objects - these will have appropriate lazy loaders attached!
my %Memcache_of       :ATTR( :get<memcache> );
my %DBcache_of        :ATTR( :get<dbcache>  );
my %DBAdaptor_of      :ATTR;
my %WebAdaptor_of     :ATTR;
my %SpeciesDefs_of    :ATTR;
my %Das_sources_of    :ATTR;
my %User_of      :ATTR( :set<user>     :get<user>     );
my %Session_of   :ATTR( :set<session>  :get<session>  );
my %Script_of    :ATTR( :set<script>   :get<script>   );
my %Species_of   :ATTR( :set<species>  :get<species>  );
my %SessionAdaptor_of :ATTR( :get<sessionadaptor> );                    # To allow it to be reset
my %NewsAdaptor_of    :ATTR( :get<newsadaptor>    );                    # To allow it to be reset
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

  if (my $user = $self->get_user) {
    foreach my $das (@{ $user->dases }) {
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

#sub dbcache {
#  my $self = shift;
#  $DBcache_of{ ident $self } ||= EnsEMBL::Web::DBCache->new({
#    'db_adaptor'   => $self->dbAdaptor
#  });
#} 
#
#sub memcache {
#  my $self = shift;
#  unless( $Memcache_of{ ident $self } ) {
#    if( 1 ) { 
#      $Memcache_of{ ident $self } = Cache::Memcached->new({
#        'servers' => [ '172.17.67.20:11211', '172.17.67.20:11212' ],
#        'debug'   => 0,
#        'compress_threshold' => 10000,
#      });
#      $Memcache_of{ ident $self }->enable_compress(0);
#    } else {
#      $Memcache_of{ ident $self } = EnsEMBL::Web::FakeMemcached->new();
#    }
#  }
#  return $Memcache_of{ ident $self };
#}

sub sessionAdaptor {
### a
### Lazy loaded Session adaptor....
  my $self = shift;
  $SessionAdaptor_of{ ident $self } ||= EnsEMBL::Web::DBSQL::SessionAdaptor->new({
#    'memcache'     => $self->memcache,
    'db_adaptor'   => $self->dbAdaptor,
    'species_defs' => $self->species_defs
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
  $arg_ref->{'cookie'}->retrieve($arg_ref->{'r'});
  my $id = $arg_ref->{'cookie'}->get_value;
  
  $self->set_user( EnsEMBL::Web::Data::User->new({
    id    => $id,
##  TODO: decide if we still need 'defer' here, and implement if yes
##  defer => 'yes',
  }) ) if $id;
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


