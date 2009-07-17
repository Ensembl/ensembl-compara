package EnsEMBL::Web::ExtURL;

use strict;
use warnings;
no warnings "uninitialized";

use CGI qw(escape);

# New now takes a secondary hash which contains a list of additional links!
sub new {
  my( $class, $species, $species_defs, %extra_urls ) = @_;
  my $self = { 'species_defs' => $species_defs, 'URLS' => {} };
  bless $self, $class;
  $self->set_species( $species, %extra_urls );
  return $self;
}

sub set_species {
  my( $self, $species, %extra_urls ) = @_;
  $self->{'species'} = $species;
  $self->{'URLS'}{$species} ||= $self->{'species_defs'}->ENSEMBL_EXTERNAL_URLS||{};
  foreach ( keys %extra_urls ) {
    $self->{'URLS'}{$species}{$_} = $extra_urls{$_};
  }
}


sub get_url {
  my ($self, $db, $data )=@_;
  if( defined($data) and ref($data) ne 'HASH' ){
    $data = { 'ID' => $data }
  }
  my $species        = $self->{'species'};
  $data->{'SPECIES'} ||= $species;
  $data->{'DB'}      = $db;
## Sets URL to the the entry for the given name, OR the default value OTHERWISE returns....
  my $url= $self->{'URLS'}{$species}{ uc($db) } || $self->{'URLS'}{$species}{'DEFAULT'};
  $url =~ s/###(\w+)###/CGI->escape( exists $data->{$1} ? $data->{$1} : "(($1))" )/ge;
  return CGI->escapeHTML($url);
}

sub is_linked{ return exists $_[0]->{'URLS'}{$_[0]->{'species'}}{uc($_[1])}; }

1;
