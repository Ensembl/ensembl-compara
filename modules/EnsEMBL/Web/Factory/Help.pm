package EnsEMBL::Web::Factory::Help;

use strict;

use EnsEMBL::Web::Factory;
use EnsEMBL::Web::Proxy::Object;
use EnsEMBL::Web::DBSQL::HelpAdaptor;
our @ISA = qw(EnsEMBL::Web::Factory);

sub help_adaptor {
  my $self = shift;
  unless( $self->__data->{'help_db'} ) {
    my $DB = $self->species_defs->databases->{'ENSEMBL_WEBSITE'};
    unless( $DB ) {
      $self->problem( 'Fatal', 'Help Database', 'Do not know how to connect to help database');
      return undef;
    }
    $self->__data->{'help_db'} ||= EnsEMBL::Web::DBSQL::HelpAdaptor->new( $DB );
  } 
  return $self->__data->{'help_db'};
}

sub createObjects { 
  my $self         = shift;
  my $keywords     = $self->param( 'kw' );
  my $single_entry = $self->param( 'se' );
  my $form         = $self->param( 'form' );

  my $results    = [];
  my $index = [];
  if( $self->param('se') || $self->param('form') ) {
    $results = $self->help_adaptor->fetch_all_by_keyword( $keywords );
  } else {
    $results = $self->help_adaptor->fetch_all_by_string( $keywords );
  }
  $index = $self->help_adaptor->fetch_index_list;

  $self->DataObjects( new EnsEMBL::Web::Proxy::Object(
    'Help', {
      'index'   => $index,
      'results' => $results,
    }, $self->__data
  ) ); 
}

1;
