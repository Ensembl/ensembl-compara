package EnsEMBL::Web::ExtIndex::ENSEMBL_RETRIEVE;

use strict;

sub new { my $class = shift; my $self = {}; bless $self, $class; return $self; }

sub get_seq_by_id {
    my ($self, $arghashref)=@_;
    my $reg = "Bio::EnsEMBL::Registry";

    #get full species name from the external_db name and species_defs
    my ($db,$sp,$type) = split '_',$arghashref->{'DB'};
    $sp = lc($sp);
    my $species = $arghashref->{'species_defs'}->species_full_name($sp);
    my $ID = $arghashref->{'ID'};

    my $seq;
    my $pep_seq = '';

    #retrieve peptide sequence
    #- for translations use stable ID mapping to account for retired IDs
    if ($type eq 'TRANSLATION') {
	my $archStableIdAdap = $reg->get_adaptor($species, 'core', 'ArchiveStableId');
	my $obj = $archStableIdAdap->fetch_by_stable_id($ID);
	my $all_records = $obj->get_all_associated_archived;
	return [] unless @$all_records;
	my @sorted_records = sort { $a->[0]->release <=> $b->[0]->release ||
				$a->[0]->stable_id cmp $b->[0]->stable_id } @$all_records;
	$pep_seq = $sorted_records[0]->[3];
	$seq = [ ">$ID" ];
    }
    #- for genes and transcripts only search the current IDS since I don't know how to get these archived IDS for these
    elsif ($type eq 'GENE') {
	my $gene_adap = $reg->get_adaptor($species, 'core', 'Gene');
	if (my $gene = $gene_adap->fetch_by_stable_id($ID)) {
	    foreach my $trans (@{$gene->get_all_Transcripts()}) {
		if (my $trl = $trans->translation) {
		    if ( length($trl->seq) > length($pep_seq) ) {
			$pep_seq =  $trl->seq;
			my $id = $trl->stable_id;
			$seq = [ ">$id" ];
		    }
		}
	    }
	}
    }
    elsif ($type eq 'TRANSCRIPT') {
	my $trans_adap = $reg->get_adaptor($species, 'core', 'Transcript');
	if (my $trans = $trans_adap->fetch_by_stable_id($ID)) {
	    if (my $trl = $trans->translate) {
		$pep_seq =  $trl->seq;
		my $id = $trl->stable_id;
		$seq = [ ">$id" ];
	    }
	}
    }

    return [] if (! $pep_seq);

    #generate arrayref of header and amino acid sequence ready for using by WISE2
    my $pos = 0;
    while ( $pos < length($pep_seq) ) {
	my $substr = substr($pep_seq,$pos,60);
	$substr .= "\n";
	push @{$seq}, $substr;
	$pos += 60;
    }
    return $seq ;
}

1;
