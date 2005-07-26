package EnsEMBL::Web::Object::Domain;

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Object;
use EnsEMBL::Web::Proxy::Factory;
our @ISA = qw(  EnsEMBL::Web::Object );

sub domainAcc  { return $_[0]->Obj->primary_id; }
sub domainDesc { return $_[0]->Obj->description; }

sub get_all_genes{
  my $self = shift;
  unless( $self->__data->{'_geneDataList'} ) {
    my $genefactory = EnsEMBL::Web::Proxy::Factory->new( 'Gene', $self->__data );
       $genefactory->createGenesByDomain( $self->domainAcc );
    $self->__data->{'_geneDataList'} = $genefactory->DataObjects;
  }
  return $self->__data->{'_geneDataList'};
}

1;
