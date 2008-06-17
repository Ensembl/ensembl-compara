package EnsEMBL::Web::Object::UserData;
                                                                                   
use strict;
use warnings;
no warnings "uninitialized";
                                                                                   
use Bio::EnsEMBL::ExternalData::DAS::DAS;
use Bio::EnsEMBL::ExternalData::DAS::DASAdaptor;
use EnsEMBL::Web::Object;
use EnsEMBL::Web::RegObj;
                                                                                   
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

sub get_ensembl_das {
### Returns an array ref of pre-configured DAS servers
  my $self = shift;
  my @domains = ();

  push( @domains, @{$self->species_defs->ENSEMBL_DAS_SERVERS || []});
  push( @domains, map{$_->adaptor->domain} @{$self->get_das_objects} );
  push( @domains, $self->param("preconf_das")) if ($self->param("preconf_das") ne $self->species_defs->DAS_REGISTRY_URL);

  my @urls;
  foreach my $url (sort @domains) {
    next unless $url;
    $url = "http://$url" if ($url !~ m!^\w+://!);
    $url .= "/das" if ($url !~ /\/das$/);
    push @urls, $url;
  }
  my %known_domains = map { $_ => 1} grep{$_} @urls ;
  return  sort keys %known_domains;
}

sub get_server_dsns {
  my $self = shift;
  if (!$self->param('das_server')) {
    return 'No domain selected - please try again';
  }

  ## Set up some (optional) filters for checking the DSNs
  my $filterT = sub { return 1; };
  my $filterM = sub { return 1; };
  my $keyText = $self->param('keyText');
  my $keyMapping = $self->param('keyMapping');
  if (defined (my $dd = $self->param('_das_filter'))) {
    if ($keyText) {
      $filterT = sub { 
        my $src = shift; 
        return 1 if ($src->{url} =~ /$keyText/); 
        return 1 if ($src->{name} =~ /$keyText/); 
        return 1 if ($src->{description} =~ /$keyText/); 
        return 0;
      };
    }
    if ($keyMapping ne 'any') {
      $filterM = sub { 
        my $src = shift; 
        foreach my $cs (@{$src->{mapping_type}}) {
          return 1 if ($cs eq $keyMapping);
        }
        return 0; 
      };
    }
  }

  ## Get DSNs
  my $adaptor = Bio::EnsEMBL::ExternalData::DAS::DASAdaptor->new( 
      -url  => $self->param('das_server'), -timeout   => $self->species_defs->ENSEMBL_DAS_TIMEOUT,
      #-proxy_url => $self->species_defs->ENSEMBL_WWW_PROXY,
      -proxy_url => 'http://webcache.sanger.ac.uk:3128' 
  );
  my $das = Bio::EnsEMBL::ExternalData::DAS::DAS->new ( $adaptor );
  my %dsnhash = map {$_->{id}, $_} grep {$filterT->($_)} @{ $das->fetch_dsn_info };
  if (keys %dsnhash) {
    return \%dsnhash;
  }
  else { 
    return 'No DSNs found on this DAS server. Please select another server.';
  }
}

sub get_das_objects {
### replacement for DASCollection Factory code
  my $self = shift;
  my $das_objs = [];
  return $das_objs;
}


1;
