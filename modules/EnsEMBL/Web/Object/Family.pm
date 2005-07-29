package EnsEMBL::Web::Object::Family;

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Object;
our @ISA = qw( EnsEMBL::Web::Object );

sub stable_id         { return $_[0]->Obj->stable_id; }
sub description       { return $_[0]->Obj->description; }
sub description_score { return $_[0]->Obj->description_score; }
sub member_by_source  { return $_[0]->Obj->get_Member_Attribute_by_source($_[1]) || []; }

sub taxonomy_id       { return $_[0]->database('core')->get_MetaContainer->get_taxonomy_id(); }

=head2 taxa

  Arg[1]      : family object
  Example     : my @taxa = @{ $self->DataObj->taxa($family) };
  Description : returns the taxa
  Return type : arrayref

=cut

sub taxa {
  my $self   = shift;
  my $family = shift;
  my $taxon_adaptor = $family->adaptor->db->get_TaxonAdaptor;
  my $taxa = $taxon_adaptor->fetch_by_Family_Member_source($family, 'ENSEMBLPEP');
  return $taxa || [];
}


=head2 source_taxon

  Arg[1]      : source taxon e.g ENSEMBLPEP
  Example     : my @taxa = @{ 	$self->DataObj->source_taxon("ENSEMBLPEP") };
  Description : returns the family members
  Return type : arrayref

=cut

sub source_taxon {
  my $self = shift;
  my $source_taxon = shift;
  my $id = shift;
  return $self->Obj->get_Member_Attribute_by_source_taxon($source_taxon, $id) || [];
}


=head2 check_chr

  Arg[1]      : 
  Example     : return unless $self->DataObj->check_chr
  Description : checks species defs for chromosomes
  Return type : int.

=cut

sub check_chr {
  my $self = shift;
  return @{$self->species_defs->ENSEMBL_CHROMOSOMES} ? 1 : 0;
}

sub get_all_genes{
  my $self = shift;
  unless( $self->__data->{'_geneDataList'} ) {
    my $genefactory = EnsEMBL::Web::Proxy::Factory->new( 'Gene', $self->__data );
       $genefactory->createGenesByFamily( $self );
    $self->__data->{'_geneDataList'} = $genefactory->DataObjects;
  }
  return $self->__data->{'_geneDataList'};
}


=head2 gene

  Arg[1]      : 
  Example     : 
  Description : 
  Return type : hashref

=cut

sub gene {
  my $self = shift;
  my $id = shift;
  my $dbs = $self->DBConnection->get_DBAdaptor('core');
  my $gene_adaptor = $dbs->get_GeneAdaptor;
  my $gene = $gene_adaptor->fetch_by_stable_id($id,1 );

  return {} unless $gene;
  my $gene_data = {
    'id'       => $id,
    'region'   => $gene->slice->seq_region_name,
    'start'    => $gene->start,
    'end'      => $gene->end,
    'strand'   => $gene->strand,
    'length'   => $gene->end - $gene->start +1,
    'extname'  => $gene->external_name,
    'label'    => $gene->stable_id,
    'desc'     => $gene->description,
    'coord_system' => $gene->slice->coord_system_name,
    'extra'    => [ $gene->description ]
  };
  return $gene_data;
}

1;
