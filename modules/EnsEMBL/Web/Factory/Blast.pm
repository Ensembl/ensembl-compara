package EnsEMBL::Web::Factory::Blast;

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Factory;
use EnsEMBL::Web::Proxy::Object;
use EnsEMBL::Web::DBSQL::BlastAdaptor;
use EnsEMBL::Web::Object::BlastRequest;
use EnsEMBL::Web::Object::BlastTicket;

our @ISA = qw(  EnsEMBL::Web::Factory );

sub blast_adaptor {
  my $self = shift;
  warn ("Loading fonts from: " . $self->species_defs->{'ENSEMBL_FONT_LOCATION'});
  my $DB = $self->species_defs->databases->{'ENSEMBL_BLAST'};
  unless ($DB) {
    $self->problem('Fatal', 'Blast database', 'Configuration not found for Blast database');
    return undef;
  }
  $self->__data->{'blast_db'} ||= EnsEMBL::Web::DBSQL::BlastAdaptor->new($DB);
  return $self->__data->{'blast_db'};
}

sub createObjects {   
    my $self = shift;    
    my $current_version = $self->species_defs->ENSEMBL_VERSION;
    my $current_species_list = $self->blast_adaptor->fetch_species($current_version);

    $self->DataObjects(EnsEMBL::Web::Proxy::Object->new( 
           'Blast', { 
           'current_spp' => $current_species_list,
           'request' => EnsEMBL::Web::Object::BlastRequest->new,
           'ticket' => EnsEMBL::Web::Object::BlastTicket->new({
				'blast_adaptor' => $self->blast_adaptor
				}),
           'blast_adaptor' => $self->blast_adaptor,
           }, 
           $self->__data ));
}

1;
