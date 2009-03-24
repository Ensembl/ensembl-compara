package Bio::EnsEMBL::Compara::DBSQL::AnchorSeqAdaptor;

use strict;
use Bio::EnsEMBL::DBSQL::BaseAdaptor;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw warning);

our @ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor);


sub store {
  my ($self, @args) = @_;
  my ($anchor_id, $dnafrag_id, $start, $end, $strand, $mlssid, $test_mlssid, $sequence) = 
	rearrange([qw(ANCHOR_ID, DNAFRAG_ID, START, END, STRAND, MLSSID, SEQUENCE, LENGTH)], @args);


  my $dcs = $self->dbc->disconnect_when_inactive();
  $self->dbc->disconnect_when_inactive(0);
  
  $self->dbc->do("LOCK TABLE anchor_sequence WRITE");
  my $length = length($sequence);

  my $sth = $self->prepare("INSERT INTO anchor_sequence (sequence, 
	length, dnafrag_id, start, end, strand, anchor_id, method_link_species_set_id) VALUES (?,?,?,?,?,?,?,?)");	  
  $sth->execute($sequence, $length, $dnafrag_id, $start, $end, $strand, $anchor_id, $mlssid);
  $sth->finish;
  $self->dbc->do("UNLOCK TABLES");
  $self->dbc->disconnect_when_inactive($dcs);
}

sub get_anchor_sequences {
	my ($self, $anc_ids_from_to) = @_;
        my $sth = $self->prepare("SELECT a.anchor_id, df.genome_db_id, a.dnafrag_id, a.start, a.end, a.strand, a.sequence 
                FROM anchor_sequence a INNER JOIN dnafrag df ON a.dnafrag_id = df.dnafrag_id WHERE a.anchor_id 
                BETWEEN ? AND ? order by a.anchor_id");

#	my $sth = $self->prepare("SELECT anchor_id, anchor_seq_id, dnafrag_id, start, end, strand, sequence 
#		FROM anchor_sequence WHERE anchor_id BETWEEN ? AND ? order by anchor_id");
	$sth->execute($anc_ids_from_to->[0], $anc_ids_from_to->[1]);
	my $anchor_array_ref = $sth->fetchall_arrayref;	
	return $anchor_array_ref;
}

1;

