

use strict;

open(S,"/scratch4/ensembl/birney/static_mouse.txt");

my %contig;

while( <S> ) {
    my ($id,$chr,$start,$end,$raw_start,$raw_end,$raw_ori) = split;
    my $h = {};
    #print STDERR "Storing $chr,$start,$end for $id\n";
    $h->{'chr'} = $chr;
    $h->{'start'} = $start;
    $h->{'end'} = $end;
    $h->{'raw_start'} = $raw_start;
    $h->{'raw_end'} = $raw_end;
    $h->{'raw_ori'} = $raw_ori;
    $contig{$id} = $h;
}



my $glob = 50;
$| = 1;
my ($current_start,$current_end,$prev_id,$current_m_start,$current_m_end,$current_strand);

while( <> ) {
    my ($align_id,$d,$human_id,$start,$end,$mouse_id,$m_start,$m_end,$strand) = split;
    #print STDERR "Seeing $align_id vs $prev_id $current_end $start\n";
    
    if( !defined $prev_id ) {

	# first contig
	$current_start = $start;
	$current_end   = $end;
	$prev_id       = $align_id;
	$current_m_start = $m_start;
	$current_m_end   = $m_end;
	$current_strand  = $strand;
    } elsif( $align_id == $prev_id && ($current_end + $glob) > $start ) {
	# globbed. Simply extend end and worry about m_start and m_end
	#print STDERR "globbed out\n";

	$current_end = $end;
	if( $m_start < $current_m_start ) {
	    $current_m_start = $m_start;
	}
	if( $m_end  > $current_m_end ) {
	    $current_m_end = $m_end;
	}
    } else {
	# write the block out
	#print STDERR "Writing out\n";
	# first map mouse to chromosomal coordinates

	# protect us against micro-matches... why do we have them?
	my $min_size = 30;
	if( $current_end - $current_start < $min_size || $current_m_end - $current_m_start < $min_size ) {
	    $current_start = $start;
	    $current_end   = $end;
	    $prev_id       = $align_id;
	    $current_m_start = $m_start;
	    $current_m_end   = $m_end;
	    $current_strand  = $strand;
	    next;
	}
	
	my $h = $contig{$mouse_id};
	my ($chr_start,$chr_end,$chr_strand);

	if( $h->{'raw_ori'} == 1 ) {
	    $chr_start = $h->{'start'} + $current_m_start - $h->{'raw_start'} +1;
	    $chr_end   = $h->{'start'} + $current_m_end - $h->{'raw_start'} +1;
	} else {
	    $chr_start = $h->{'start'} + $h->{'raw_end'} - $current_m_end;
	    $chr_end   = $h->{'start'} + $h->{'raw_end'} - $current_m_start;
	    $chr_strand = -1 * $current_strand;
	}

	# now figure out where this is on denormalised coordinates

	my ($de_scontig_id,$de_start) = &map_to_denormalised($h->{'chr'},$chr_start);
	my ($de_econtig_id,$de_end)   = &map_to_denormalised($h->{'chr'},$chr_end);

	#print STDERR "Got $de_scontig_id vs $de_econtig_id $chr_start $chr_end\n";

	# if we cross boundaries - currently skip!

	if( $de_scontig_id eq $de_econtig_id ) {
	    # dump it
	    print "$human_id\t$current_start\t$current_end\t1\t$de_scontig_id\t$de_start\t$de_end\t$current_strand\n";
	}

	$current_start = $start;
	$current_end   = $end;
	$prev_id       = $align_id;
	$current_m_start = $m_start;
	$current_m_end   = $m_end;
	$current_strand  = $strand;
    } 
}


sub map_to_denormalised {
    my ($chr,$pos) = @_;

    my $block = int($pos / 5000000);

    my $start = ($block * 5000000) +1;
    my $end   = ($block+1) * 5000000;

    my $rem   = $pos - $start +1; # plus 1 for 'biological' coordinates

    my $id = $chr.".".$start."-".$end;


    return ($id,$rem);
}











