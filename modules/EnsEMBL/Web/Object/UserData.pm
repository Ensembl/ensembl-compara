package EnsEMBL::Web::Object::UserData;
                                                                                   
use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Object;
use EnsEMBL::Web::RegObj;
use Bio::EnsEMBL::Utils::Exception qw(try catch);
use Bio::EnsEMBL::ExternalData::DAS::SourceParser; # for contacting DAS servers
                                                                                   
our @ISA = qw(EnsEMBL::Web::Object);


sub data        : lvalue { $_[0]->{'_data'}; }
sub data_type   : lvalue {  my ($self, $p) = @_; if ($p) {$_[0]->{'_data_type'} = $p} return $_[0]->{'_data_type' }; }

sub caption           {
  my $self = shift;
  return 'Custom Data';
}

sub short_caption {
  my $self = shift;
  return 'Data Management';
}

sub counts {
  my $self = shift;
  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  my $counts = {};
  return $counts;
}

sub get_das_servers {
### Returns a hash ref of pre-configured DAS servers
  my $self = shift;
  
  my @domains = ();
  my @urls    = ();

  my $reg_url = $self->species_defs->get_config('MULTI', 'DAS_REGISTRY_URL');
  my $reg_name = $self->species_defs->get_config('MULTI', 'DAS_REGISTRY_NAME') || $reg_url;

  push( @domains, {'name'  => $reg_name, 'value' => $reg_url} );
  my @extras = @{$self->species_defs->get_config('MULTI', 'ENSEMBL_DAS_SERVERS')};
  foreach my $e (@extras) {
    push( @domains, {'name' => $e, 'value' => $e} );
  }
  #push( @domains, {'name' => $self->param('preconf_das'), 'value' => $self->param('preconf_das')} );

  # Ensure servers are proper URLs, and omit duplicate domains
  my %known_domains = ();
  foreach my $server (@domains) {
    my $url = $server->{'value'};
    next unless $url;
    next if $known_domains{$url};
    $known_domains{$url}++;
    $url = "http://$url" if ($url !~ m!^\w+://!);
    $url .= "/das" if ($url !~ /\/das1?$/);
    $server->{'name'}  = $url if ( $server->{'name'} eq $server->{'value'});
    $server->{'value'} = $url;
  }

  return @domains;
}

# Returns an arrayref of DAS sources for the selected server and species
sub get_das_server_dsns {
  my ($self, @logic) = @_;
  
  my $server  = $self->_das_server_param();
  my $species = $ENV{ENSEMBL_SPECIES};
  if ($species eq 'common') {
    $species = $self->species_defs->ENSEMBL_PRIMARY_SPECIES;
  }

  my $name    = $self->param('das_name_filter');
  @logic      = grep { $_ } @logic;
  my $sources;
  
  try {
    my $parser = Bio::EnsEMBL::ExternalData::DAS::SourceParser->new(
      -location => $server,
      -timeout  => $self->species_defs->ENSEMBL_DAS_TIMEOUT,
      -proxy    => $self->species_defs->ENSEMBL_WWW_PROXY,
      -noproxy  => $self->species_defs->ENSEMBL_NO_PROXY,
    );
    
    $sources = $parser->fetch_Sources(
      -species    => $species || undef,
      -name       => $name    || undef,
      -logic_name => scalar @logic ? \@logic : undef,
    );
    
    if (!$sources || !scalar @{ $sources }) {
      $sources = "No DAS sources found for $server";
    }
    
  } catch {
    warn $_;
    if ($_ =~ /MSG:/) {
      ($sources) = $_ =~ m/MSG: (.*)$/m;
    } else {
      $sources = $_;
    }
  };
  
  return $sources;
}

sub _das_server_param {
  my $self = shift;
  
  for my $key ( 'other_das', 'preconf_das' ) {
    
    # Get and "fix" the server URL
    my $server = $self->param( $key ) || next;
    
    if ($server !~ /^\w+\:/) {
      $server = "http://$server";
    }
    if ($server =~ /^http/) {
      $server =~ s|/*$||;
      if ($server !~ m{/das1?$}) {
        $server = "$server/das";
      }
    }
    $self->param( $key, $server );
    return $server;
    
  }
  
  return undef;
}

1;
