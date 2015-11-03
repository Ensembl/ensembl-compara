=pod

=head1 NAME
	
	Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::PrepareOrthologs

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

package Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::PrepareOrthologs;

use strict;
use warnings;
use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

use Bio::EnsEMBL::Registry;

=head2 fetch_input

	Description: pull orthologs for species 1 and 2 from EnsEMBL and save as param

=cut

sub fetch_input {
	my $self = shift;

	my $species1_id = $self->param_required('species1_id');
	my $species2_id = $self->param_required('species2_id');

	my $mlss_adaptor = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor;
	my $mlss = $mlss_adaptor->fetch_by_method_link_type_genome_db_ids('ENSEMBL_ORTHOLOGUES', [$species1_id, $species2_id]);

	my $current_homo_adaptor = $self->compara_dba->get_HomologyAdaptor;
	my $current_homologs     = $current_homo_adaptor->fetch_all_by_MethodLinkSpeciesSet($mlss);

	my $previous_db = $self->param('previous_rel_db');
	if ( defined $previous_db ){
		my $previous_compara_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba($previous_db);
		my $previous_homo_adaptor = $previous_compara_dba->get_HomologyAdaptor;
		my $previous_homologs     = $previous_homo_adaptor->fetch_all_by_MethodLinkSpeciesSet($mlss);

		# print "Found " . scalar(@{$current_homologs}) . " in current db\n";
		# print "Found " . scalar(@{$previous_homologs}) . " in prev db\n";

		my $updated_orthologs = $self->_updated_orthologs( $current_homologs, $previous_homologs );

		# print "Found " . scalar(@{$updated_orthologs}) . " changes\n";
		# foreach my $uo ( @{$updated_orthologs} ) {
		# 	print $uo->dbID . "\n";
		# }

		my $exons = $self->_find_exons( $updated_orthologs );

		$self->param( 'orth_objects', $updated_orthologs );
	}
	else {
		$self->param( 'orth_objects', $current_homologs );
	}
}

=head2 run

	Description: parse Bio::EnsEMBL::Compara::Homology objects to get start and end positions
	of genes

=cut

sub run {
	my $self = shift;

	my @orth_info;
	my $c = 0;

	my @orth_objects = @{ $self->param('orth_objects') };
	while ( my $orth = shift( @orth_objects ) ) {
		my @gene_members = @{ $orth->get_all_GeneMembers() };
		my (%orth_ranges, @orth_dnafrags);
		foreach my $gm ( @gene_members ){
			push( @orth_dnafrags, { id => $gm->dnafrag_id, start => $gm->dnafrag_start, end => $gm->dnafrag_end } );
			$orth_ranges{$gm->genome_db_id} = [ $gm->dnafrag_start, $gm->dnafrag_end ];
		}

		push( @orth_info, { 
			orth_id       => $orth->dbID, 
			orth_ranges   => \%orth_ranges, 
			orth_dnafrags => \@orth_dnafrags 
		} );
		# $c++;
		# last if $c >= 1000;
	}
	# print Dumper \@orth_info;
	$self->param( 'orth_info', \@orth_info );
}

=head2 write_output

	Description: send data to correct dataflow branch!

=cut

sub write_output {
	my $self = shift;

	print "Flowing to prepare_alns:\n";
	print Dumper $self->param( 'orth_info' );

	# $self->dataflow_output_id( { aln_mlss_id => $self->param('aln_mlss_id') }, 1 ); # to assign_quality
	$self->dataflow_output_id( $self->param('orth_info'), 2 ); # to prepare_alns
}

=head2 _updated_orth

	Checks whether the Homology object has been updated since the last release
	Do not recalculate if it is unchanged

=cut

sub _updated_orthologs {
	my ( $self, $current_homologs, $previous_homologs ) = @_;

	# reformat data to hashes
	my %current_hh  = %{ $self->_hash_homologs( $current_homologs ) };
	my %previous_hh = %{ $self->_hash_homologs( $previous_homologs ) };

	my @new_homologs;
	foreach my $h ( @{ $current_homologs } ){
		my $curr_id = $h->dbID;
		if ( (!defined $previous_hh{$curr_id}) || ($current_hh{$curr_id}->[0] != $previous_hh{$curr_id}->[0] || $current_hh{$curr_id}->[1] != $previous_hh{$curr_id}->[1])  ) {
			push( @new_homologs, $h );
		}
	}


	return \@new_homologs;
}

sub _hash_homologs {
	my ( $self, $hlist ) = @_;

	my %hhash;
	foreach my $h ( @{ $hlist } ) {
		my @members;
		foreach my $gene ( @{ $h->get_all_GeneMembers() } ) {
			push( @members, $gene->dbID );
		}
		my @sorted_members = sort {$a <=> $b} @members;
		$hhash{ $h->dbID } = \@sorted_members;
	}
	return \%hhash;
}

1;
