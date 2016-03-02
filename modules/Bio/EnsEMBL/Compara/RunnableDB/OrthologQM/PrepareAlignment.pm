=pod

=head1 NAME
	
	Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::PrepareAlignment

=head1 SYNOPSIS

	Fetch alignment blocks that connect the species of interest, format and dataflow

=head1 DESCRIPTION

	Inputs:
	orth_dnafrags	list of dnafrag_ids that cover each member of the homology
	orth_ranges		(only required for passthrough)
	orth_id			(only required for passthrough)
	orth_exons		(only required for passthrough)
	aln_mlss_id		method_link_species_set_id for the alignment between these spedies
	alt_aln_db		by default, alignments are fetched from the compara_db parameter.
					to use a different source, define alt_aln_db with a URL to a DB containing alignments
	species1_id		genome_db_id of first species  |
	species2_id		genome_db_id of second species |-> these are only used to limit multiple alignment blocks

	Outputs:
	Dataflow fan: { 
			gblock_id => dbID, 
			gblock_range => [start,end],
			orth_ranges  => $self->param('orth_ranges'),
			orth_id      => $self->param('orth_id'),
			orth_exons   => $self->param('orth_exons'),
		}

=cut

package Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::PrepareAlignment;

use strict;
use warnings;
use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

#use Bio::EnsEMBL::Registry;

=head2 fetch_input

	Description: pull orthologs from DB for species 1 and 2 from EnsEMBL 
	and save as param

=cut

sub fetch_input {
	my $self = shift;

	my @orth_dnafrags = @{ $self->param_required('orth_dnafrags') };
	# my %dnafrag_coords = %{ $self->param_required('dnafrag_coords') };
	my $aln_mlss_id = $self->param_required( 'aln_mlss_id' );

	my ( $mlss_adap, $gblock_adap, $dnafrag_adaptor, $dba );

	if ( $self->param('alt_aln_db') ) { $dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba($self->param('alt_aln_db')); }
	else { $dba = $self->compara_dba }
	
	my $mlss_adap       = $dba->get_MethodLinkSpeciesSetAdaptor;
	my $gblock_adap     = $dba->get_GenomicAlignBlockAdaptor;
	my $dnafrag_adaptor = $dba->get_DnaFragAdaptor;

	$self->db->dbc->disconnect_if_idle;

	my $mlss = $mlss_adap->fetch_by_dbID( $aln_mlss_id );
	
	my $s1_dnafrag = $dnafrag_adaptor->fetch_by_dbID( $orth_dnafrags[0]->{id} );
	my $s2_dnafrag = $dnafrag_adaptor->fetch_by_dbID( $orth_dnafrags[1]->{id} );

	my ($dnafrag_start, $dnafrag_end) = ( $orth_dnafrags[0]->{start}, $orth_dnafrags[0]->{end} );
	print "\n\ngblock_adap->fetch_all_by_MethodLinkSpeciesSet_DnaFrag_DnaFrag( " . $mlss->dbID . ', ' . $s1_dnafrag->dbID . ", $dnafrag_start, $dnafrag_end, " . $s2_dnafrag->dbID . " );\n";
	my $gblocks = $gblock_adap->fetch_all_by_MethodLinkSpeciesSet_DnaFrag_DnaFrag( $mlss, $s1_dnafrag, $dnafrag_start, $dnafrag_end, $s2_dnafrag );

	#print "FETCH_INPUT: found " . scalar( @{ $gblocks } ) . " GenomicAlignBlocks!!\n";
	#print Dumper $gblocks;

	$self->param( 'genomic_align_blocks', $gblocks );
	#$self->param( 'nonref_info', { 'dnafrag' => $orth_dnafrags[1], 'coordinates' => $dnafrag_coords{$orth_dnafrags[1]} } );

    my %aln_ranges;
    # while ( my $gblock = shift @{ $gblocks }  ){
    foreach my $gblock ( @{$gblocks} ) {
    	foreach my $ga ( @{ $gblock->get_all_GenomicAligns } ) {
	        my $current_gdb = $ga->genome_db->dbID;
	        # limit multiple alignment blocks to only the species of interest
	        next unless ( $current_gdb == $self->param_required( 'species1_id' ) || $current_gdb == $self->param_required( 'species2_id' ) );
	        $aln_ranges{$gblock->dbID}->{$current_gdb} = [ $ga->dnafrag_start, $ga->dnafrag_end];
	    }
    }    

    #print "ALN COORDS: ";
    #print Dumper \@aln_ranges;

    $self->param( 'aln_ranges', \%aln_ranges );
}

=head2 run

	Description: parse Bio::EnsEMBL::Compara::Homology objects to get start and end positions
	of genes

=cut

sub run {
	my $self = shift;

	my @fan;
	my %aln_ranges = %{ $self->param('aln_ranges') };
	my @gblocks    = @{ $self->param('genomic_align_blocks') };

	#print "RUN: imported " . scalar( @gblocks ) . " gblocks!!\n";

	# print "ALN_RANGES:\n";
	# print Dumper \%aln_ranges;

	foreach my $gblock ( @gblocks ) {
		push( @fan, { 
			gblock_id => $gblock->dbID, 
			gblock_range => $aln_ranges{$gblock->dbID},
			orth_ranges  => $self->param('orth_ranges'),
			orth_id      => $self->param('orth_id'),
			orth_exons   => $self->param('orth_exons'),
		} );
	}

	$self->param( 'fan', \@fan );
}

=head2 write_output

	Description: send data to correct dataflow branch!

=cut

sub write_output {
	my $self = shift;

	my $funnel_dataflow = {
		aln_ranges  => $self->param('aln_ranges'),
		orth_ranges => $self->param('orth_ranges'),
		orth_id     => $self->param('orth_id'),
		orth_exons  => $self->param('orth_exons'),
	};

	$self->dataflow_output_id( $self->param('fan'), 2 ); # to orth_v_aln 
	$self->dataflow_output_id( $funnel_dataflow, 1 ); # to combine_coverage
}

1;