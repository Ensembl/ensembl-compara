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

    #retrieve details of stable ids - use stable ID mapping to account for retired IDs
    my $ID = $arghashref->{'ID'};
    my $archStableIdAdap = $reg->get_adaptor($species, 'core', 'ArchiveStableId');
    my $obj = $archStableIdAdap->fetch_by_stable_id($ID);
    my $all_records = $obj->get_all_associated_archived;
    my @sorted_records = sort { $a->[0]->release <=> $b->[0]->release ||
				$a->[0]->stable_id cmp $b->[0]->stable_id } @$all_records;

    #generate arrayref of header and amino acid sequence ready for using by WISE2
    my $seq = [ ">$ID" ];
    my $pos = 0;
    my $pep_seq = $sorted_records[0]->[3];
    while ( $pos < length($pep_seq) ) {
	my $substr = substr($pep_seq,$pos,60);
	$substr .= "\n";
	push @{$seq}, $substr;
	$pos += 60;
    }
    return $seq ;
}

1;
