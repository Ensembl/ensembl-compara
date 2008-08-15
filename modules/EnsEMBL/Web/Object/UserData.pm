package EnsEMBL::Web::Object::UserData;
                                                                                   
use strict;
use warnings;
no warnings "uninitialized";
=head
# TODO: remove these                                                                                   
use Bio::EnsEMBL::ExternalData::DAS::DAS;
use Bio::EnsEMBL::ExternalData::DAS::DASAdaptor;
=cut
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
### Returns an array ref of pre-configured DAS servers
  my $self = shift;
  
  my @domains = ();
  my @urls    = ();

  push( @domains, $self->species_defs->DAS_REGISTRY_URL );
  push( @domains, @{$self->species_defs->ENSEMBL_DAS_SERVERS || []});
  push( @domains, $self->param('preconf_das') );

  # Ensure servers are proper URLs
  foreach my $url (@domains) {
    next unless $url;
    $url = "http://$url" if ($url !~ m!^\w+://!);
    $url .= "/das" if ($url !~ /\/das1?$/);
    push @urls, $url;
  }
  
  # Filter duplicates
  my %known_domains = map { $_ => 1} grep{$_} @urls ;
  return sort keys %known_domains;
}

# Returns an arrayref of DAS sources for the selected server and species
sub get_das_server_dsns {
  my $self = shift;
  
  my $server = $self->param('das_server');
  if ($server =~ /^http/) {
    $server =~ s|/*$||;
    if ($server !~ m{/das$}) {
      $server = "$server/das";
    }
  }
  my $sources;
  
  try {
    my $parser = Bio::EnsEMBL::ExternalData::DAS::SourceParser->new(
      -location => $server,
      -timeout  => $self->species_defs->ENSEMBL_DAS_TIMEOUT,
      -proxy    => $self->species_defs->ENSEMBL_WWW_PROXY,
      -noproxy  => $self->species_defs->ENSEMBL_NO_PROXY,
    );
    
    $sources = $parser->fetch_Sources(
      -species => $self->species_defs->name,
      -name    => $self->param('das_filter'), # A filter, if specified
    );
    
    if (!$sources || !scalar @{ $sources }) {
      $sources = 'No DAS sources found for this species';
    }
    
  } catch {
    ($sources) = $_ =~ m/MSG: (.*)$/m;
  };
  
  return $sources;
}

1;
