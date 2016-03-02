=pod

=head1 NAME
    
    Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::PrepareExons

=head1 SYNOPSIS

	Find and format the start/end positions for the exons for each member of a given homology_id

=head1 DESCRIPTION

    Input(s):
    orth_id         homology dbID
    orth_ranges     formatted hash of start/end positions of homologs (just for passthrough)
    orth_dnafrags   list of dnafrags included in homologs (just for passthrough)

    Outputs:
    hash combining all given ortholog info + exon boundaries

=cut


package Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::PrepareExons;

use strict;
use warnings;
use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

use Bio::EnsEMBL::Registry;

sub fetch_input {
    my $self = shift;

    my $orth_id    = $self->param_required( 'orth_id' );
    unless ( $self->param( 'orth_exons' ) ) { $self->param( 'orth_exons', $self->_fetch_exons( $orth_id ) ) };
}

sub write_output {
    my $self = shift;

    my $dataflow = {
    	orth_id       => $self->param('orth_id'), 
		orth_ranges   => $self->param('orth_ranges'), 
		orth_dnafrags => $self->param('orth_dnafrags'),
		orth_exons    => $self->param('orth_exons'),
    };

    $self->dataflow_output_id( $dataflow, 1 );
}

=head2 _fetch_exons

    Description: fetch exon coordinates for each gene member in the homology

    Returns: hash of exon coordinates; key = genome_db_id; value = array of exon coordinates

=cut

sub _fetch_exons {
    my ( $self, $orth_id ) = @_;

    my %orth_exons;

    my $hom_adapt = $self->compara_dba->get_HomologyAdaptor;
    my $homology  = $hom_adapt->fetch_by_dbID( $orth_id );

    my $gene_members = $homology->get_all_GeneMembers();
    foreach my $gm ( @{ $gene_members } ) {
        $orth_exons{ $gm->genome_db_id } = [];
        my $seqmems = $gm->get_all_SeqMembers;
        foreach my $sm ( @{ $seqmems } ) {
            my $transcript = $sm->get_Transcript;

            my $exon_list;
            print "\nsource_name: " . $sm->source_name . "\n";
            if    ( $sm->source_name =~ "PEP"   ) { $exon_list = $transcript->get_all_translateable_Exons }
            elsif ( $sm->source_name =~ "TRANS" ) { $exon_list = $transcript->get_all_Exons }

            foreach my $exon ( @{ $exon_list } ) {
                my @ex_coords = ( $exon->start, $exon->end );
                push( @{ $orth_exons{ $gm->genome_db_id } }, \@ex_coords );
            }
        }
    }

    my $uniq_exons = $self->_unique_exons(\%orth_exons);

    return $uniq_exons;
}

=head2 _unique_exons

	Description: take hash structure of exon ranges and remove duplicates

=cut

sub _unique_exons {
	my ($self, $exons) = @_;

	my %uniq;
	foreach my $gdb ( keys %{ $exons } ) {
		foreach my $range ( @{ $exons->{$gdb} } ) {
			my $str_range = join('-', @{ $range });
			$uniq{$str_range} = $gdb;
		}
	}

	my %u_exons;
	foreach my $str_range ( keys %uniq ) {
		my $gdb = $uniq{$str_range};
		my @unstr_range = split('-', $str_range);
		push( @{ $u_exons{$gdb} }, \@unstr_range );
	}

	return \%u_exons;
}



1;