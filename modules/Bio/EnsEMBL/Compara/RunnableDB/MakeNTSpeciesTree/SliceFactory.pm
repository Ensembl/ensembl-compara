#you may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::MakeNTSpeciesTree::SliceFactory

=cut

=head1 SYNOPSIS

=cut

package Bio::EnsEMBL::Compara::RunnableDB::MakeNTSpeciesTree::SliceFactory;

use strict;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::Exception;
use Data::Dumper;

use base('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
 my $self = shift @_;
 my $msa_genome_id = $self->param('msa_mlssid_and_reference_species')->{$self->param('msa_mlssid')};
 my $genome_db_a = $self->compara_dba->get_adaptor("GenomeDB");
 my $ref_genome_db = $genome_db_a->fetch_by_dbID($msa_genome_id);
 my $ref_genome_db_name = $ref_genome_db->name;
 Bio::EnsEMBL::Registry->load_registry_from_multiple_dbs( @{ $self->param('core_dbs') } );
 my $slice_a = Bio::EnsEMBL::Registry->get_adaptor( "$ref_genome_db_name", "core", "Slice");
 my @Slices;
 my $coord_system_name = $self->param('coord_system_name') || "toplevel";
 foreach my $slice(@{ $slice_a->fetch_all("$coord_system_name") }){
  push(@Slices, { 'slice_name' => $slice->seq_region_name, 'ref_species_name' => $ref_genome_db_name, 'msa_mlssid' => $self->param('msa_mlssid') });
 }
 $self->param('ref_slices', \@Slices);
}

sub write_output {
 my $self = shift @_;
 $self->dataflow_output_id($self->param('ref_slices'), 2);
}


1;

