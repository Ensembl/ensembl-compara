#ensembl module for bio::ensembl::compara::production::epoanchors::dumpgenomesequence
# you may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code
=head1 NAME

Bio::EnsEMBL::Compara::Production::EPOanchors::DumpGenomeSequence

=head1 SYNOPSIS

$exonate_anchors->fetch_input();
$exonate_anchors->write_output(); writes to disc and database

=head1 DESCRIPTION

module to set dump the genome sequence of a given species

=head1 AUTHOR - compara

This modules is part of the Ensembl project http://www.ensembl.org

Email compara@ebi.ac.uk

=head1 CONTACT

This modules is part of the EnsEMBL project (http://www.ensembl.org)

Questions can be posted to the ensembl-dev mailing list:
dev@ensembl.org


=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut
#
package Bio::EnsEMBL::Compara::Production::EPOanchors::DumpGenomeSequence;

use strict;
use Data::Dumper;
use File::Path qw(make_path remove_tree);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
	my ($self) = @_;
	my $seq_dump_loc = $self->param('seq_dump_loc');
	$seq_dump_loc = $seq_dump_loc . "/" . $self->param('genome_db_name') . "_" . $self->param('genome_db_assembly');
	make_path("$seq_dump_loc", {verbose => 1,});
	my $genome_db_adaptor = $self->compara_dba()->get_adaptor("GenomeDB");
	my $genome_db = $genome_db_adaptor->fetch_by_dbID( $self->param('genome_db_id') );
	my $dnafrag_adaptor = $self->compara_dba()->get_adaptor("DnaFrag");
	open(IN, ">$seq_dump_loc/genome_seq") or die "cant open $seq_dump_loc\n";
	foreach my $ref_dnafrag( @{ $dnafrag_adaptor->fetch_all_by_GenomeDB_region($genome_db) } ){
		next unless $ref_dnafrag->is_reference;
		next if ($ref_dnafrag->name=~/MT.*/i and $self->param('dont_dump_MT'));
		my $header = ">" . join(":", $ref_dnafrag->coord_system_name, $genome_db->assembly,
			$ref_dnafrag->name, 1, $ref_dnafrag->length, 1);
		print IN $header, "\n";
		my $slice = $ref_dnafrag->slice;
		print IN $ref_dnafrag->slice->seq, "\n";
	}
	close(IN);
	my $batch_size = $self->param('anchor_batch_size');
	if($batch_size){
		my $anchor_dba = new Bio::EnsEMBL::DBSQL::DBAdaptor( %{ $self->param('compara_anchor_db') } );
		my $sth = $anchor_dba->dbc->prepare("SELECT anchor_id, COUNT(*) ct FROM anchor_sequence GROUP BY anchor_id");
		$sth->execute();
		my $count = 1;
		my @anchor_ids;
		my $anchor_string;
		while( my $ref = $sth->fetchrow_arrayref() ){
			next if($ref->[1] > $self->param('anc_seq_count_cut_off'));
			if($count % $batch_size){
				$anchor_string .= $ref->[0] . ",";
			}else{
				$anchor_string .= $ref->[0];
				push(@anchor_ids, { 'anchor_ids' => "$anchor_string", 'genome_db_id' => $self->param('genome_db_id') });
				$anchor_string = "";
			}
			$count++;
		}
		$self->param('query_and_target', \@anchor_ids);	
	}
}

sub write_output {
	my ($self) = @_;
	return unless $self->param('query_and_target');
	$self->dataflow_output_id( $self->param('query_and_target'), 2);
}

1;

