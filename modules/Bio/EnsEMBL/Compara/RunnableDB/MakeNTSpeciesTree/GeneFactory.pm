#you may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::MakeNTSpeciesTree::GeneFactory

=cut

=head1 SYNOPSIS

=cut

package Bio::EnsEMBL::Compara::RunnableDB::MakeNTSpeciesTree::GeneFactory;

use strict;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::Exception;
use Data::Dumper;

use base('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
 my $self = shift @_;
 Bio::EnsEMBL::Registry->load_registry_from_multiple_dbs( @{ $self->param('core_dbs') } );
 my $ref_species_name = $self->param('ref_species_name');
 my $gene_a = Bio::EnsEMBL::Registry->get_adaptor( $ref_species_name, "core", "Gene"); 
 my $slice_a = Bio::EnsEMBL::Registry->get_adaptor( $self->param('ref_species_name'), "core", "Slice");
 my $coord_system_name = $self->param('coord_system_name') || "toplevel";
 my $slice_name = $self->param('slice_name');
 my $slice = $slice_a->fetch_by_region("$coord_system_name", "$slice_name");
 my $slice_iter = $gene_a->fetch_Iterator_by_Slice( $slice );
 my ($gene, @transcript_ids);
 while($gene = $slice_iter->next){
  push(@transcript_ids, { "ref_species_name" => $ref_species_name, "transcript_id" => $gene->canonical_transcript->stable_id, "msa_mlssid" => $self->param('msa_mlssid') });
 }
 $self->param('trans_ids', \@transcript_ids);
}

sub write_output {
 my $self = shift @_;
 $self->dataflow_output_id($self->param('trans_ids'), 2) if scalar @{ $self->param('trans_ids') };
}


1;
