
use Bio::EnsEMBL::Compara::DBAdaptor;


$host = 'ecs1b';
$dbname = 'abel_compara_human_mouse';


$db = Bio::EnsEMBL::Compara::DBAdaptor( -host => $host , -dbname => $dbname , -dbuser => 'ensro');

my @ids = @ARGV;

$ga = $db->get_GenomicAlignAdaptor();


foreach $gid ( $ga->list_align_ids() ) {
    $align = $ga->fetch_by_dbID($gid);

    # assumme anchored is first

    ($anchor,$split) = $align->each_AlignBlockSet();

    if( scalar($anchor->each_AlignBlock) > 1 ) {
	print STDERR "For genomic align $gid, not anchored as first set. Skipping\n";
	next;
    }

    # assumme coordinate system *is* anchored. Therefore only needs to loop over
    # first align block

    my ($anchor_block) = $anchor->each_AlignBlock();

    if( $anchor_block->strand == -1 ) {
	print STDERR "For genomic align $gid, can't deal with reverse strand anchors. Skipping\n";
	next;
    }
    my $anchor_offset = $anchor_block->start();

    foreach my $split_block ( $split->each_AlignBlockSet() ) {
	# deduce anchor block start position

	my $anchor_start = $anchor_offset+$split_block->align_start-1;
	my $anchor_end   = $anchor_offset+$split_block->align_end-1;
	my $anchor_strand = 1;


	# output anchor_id,start,end,strand,split_id,start,end,strand

	print join('\t',$anchor_block->dnafrag->name,$anchor_start,$anchor_end,$anchor_strand,$split_block->dnafrag->name,$split_block->start,$split_block->end,$split_block->strand),"\n";
    }
}

