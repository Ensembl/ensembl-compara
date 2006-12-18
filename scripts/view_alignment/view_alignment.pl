#!/usr/local/ensembl/bin/perl -w

use strict;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::Exception qw(throw);
use Getopt::Long;

=head1 NAME
    view_alignment

=head1 AUTHORS
    Kathryn Beal (kbeal@ebi.ac.uk)

=head1 COPYRIGHT

This script is part of the Ensembl project http://www.ensembl.org

=head1 DESCRIPTION

This script finds alignments in a compara database, creates a gap4
database and brings up a contig editor for each alignment found. If the gap4 
database already exists, it will not overwrite the existing database but it 
will bring up a contig editor for each alignment. 

=head1 SETUP

The location of gap4 and view_alignment must be in your path. e.g.

in bash:

export PATH=/nfs/sids/badger/OSF/STADEN_PKGS/unix-rel-1-7-0/linux-x86_64-bin:$HOME/src/ensembl_main/ensembl_compara/scripts/view_alignment:$PATH

in csh:

setenv PATH /nfs/sids/badger/OSF/STADEN_PKGS/unix-rel-1-7-0/linux-x86_64-bin:$HOME/src/ensembl_main/ensembl_compara/scripts/view_alignment:$PATH


=head1 SYNPOSIS

view_alignment --help

view_alignment 
    [--reg_conf registry_configuration_file]
    [--compara compara_database]
    [--set_of_species species1:species2:species3...]
    [--alignment_type alignment_type]
    [--method_link_species_set_id method_link_species_set_id]
    [--species species]
    [--seq_region seq_region]
    [--seq_region_start start]
    [--seq_region_end end]
    [--genomic_align_block_id genomic_align_block_id]
    [--gap4 gap4_database]
    [--display_scores]
    [--display_constrained_element_tags]
    [--display_conservation_tags]
    [--display_start_end_tags]
    [--template_display]
    [--repeat_feature]
    
=head1 OPTIONS

=head2 GETTING HELP

=over

=item B<[--help]>

  Prints help message and exits.

=back

=head2 CONFIGURATION

=over

=item B<[--reg_conf registry_configuration_file]>

The Bio::EnsEMBL::Registry configuration file. If none given,
the one set in ENSEMBL_REGISTRY will be used if defined, if not
~/.ensembl_init will be used.

=item B<--compara compara_db_name_or_alias>

The compara database to query. You can use either the original name or any of 
the aliases given in the registry_configuration_file. 

=item B<[--set_of_species]>

The set of species used in the alignment. These should be the same as defined 
in the registry configuration file aliases. The species should be separated by 
a colon e.g. human:rat

=item B<[--alignment_type]>

This should be an exisiting method_link_type eg MLAGAN, TRANSLATED_BLAT, BLASTZ_NET

=item B<[--method_link_species_set_id]>

Instead of defining the species_set and alignment_type, you can enter the 
method_link_species_set_id instead

=item B<[--species]>

The reference species used to define the seq_region, seq_region_start and
seq_region_end. Should be the same as defined in the registry configuration
file alias.

=item B<[--seq_region]>

The name of the seq_region e.g. "17"

=item B<[--seq_region_start]>

The start of the region of interest. 

=item B<[--seq_region_end]>

The end of the region of interest

=item B<[--genomic_align_block_id]>

It is also possible to simply enter the genomic_align_block_id. This option 
will ignore the above arguments

=item B<[--display_conservation_tags]>

Tags (shown as coloured blocks in the contig editor) are created where
conservation scores have been calcalculated. Only valid if conservation
scores have been calculated for the alignment. 

=item B<[--display_constrained_element_tags]>

Tags (shown as coloured blocks in the contig editor) are created showing the
position of constrained elements (conserved regions) and their 'rejected
substitution' score. Only valid if conservation scores have been calculated for
the alignment.

=item B<[--display_scores]>

A tag (shown as a coloured block in the contig editor) is created for each 
base that has a conservation value and shows the difference between the 
expected and observed scores. This can produce a lot of tags which can take a 
long time to be read in. Only valid if conservation scores have been calculated
for the alignment. 

=item B<[--display_start_end_tags]>

This options tags the first and last base of each species in the alignment
with a tag type of "STOP" (default colour pale blue).

=item B<[--template_display]>

Automatically bring up a template display.

=item B<[--repeat_feature]>

Valid repeat feature name eg "MIR".
Tags (shown as coloured blocks in the contig editor) are created for each 
repeat found. Repeats on the forward strand assigned a tag type of "COMM" 
(default colour is blue) and repeats on the reverse strand have tag type
"OLIGO" (default colour is yellow).

=item B<[--gap4]>

A gap4 database name. This is of the format database_name.version_number e.g.
gap4_compara_17_17942309_17947928.0 If a name is not given, a default name is 
generated of the form gap4_compara_ and then either the genomic_align_block_id 
or "$seq_region_$seq_region_start_$seq_region_end" with a version value of 0. 
If the database does not already exist, the script will create a new gap4 
database of that name containing the requested alignment(s). If it does exist, 
no alignments will be added to the database and the database will simply be 
opened.

=back

=head2 EXAMPLES

Using species and alignment type:

view_alignment --reg_conf reg_conf38 --compara compara_38 --species human --set_of_species human:mouse:rat:dog:chicken:cow:opossum:macaque:chimp --alignment_type MLAGAN --seq_region "17" --seq_region_start 17942309 --seq_region_end 17947928 --gap4 a.0

Using method_link_species_set_id:

view_alignment --reg_conf reg_conf38 --compara compara_38 --species human --method_link_species_set_id 2 --seq_region "17" --seq_region_start 17942309 --seq_region_end 17943000 --gap4 a.0

Using alignment genomic align block id:

view_alignment --reg_conf reg_conf38 --compara compara_38 --genomic_align_block_id 20000032533 --gap4 a.0

Produce multiple contigs:

view_alignment --reg_conf reg_conf38 --compara compara_38 --species human --set_of_species human:mouse:rat:dog:chicken:cow:opossum:macaque:chimp --alignment_type MLAGAN --seq_region "17" --seq_region_start 1488850 --seq_region_end 1532082 --gap4 a.0

Blastz_net alignment (produces 5 alignments)

view_alignment --reg_conf reg_conf38 --compara compara_38 --species human --set_of_species human:mouse --alignment_type BLASTZ_NET --seq_region "17" --seq_region_start 17942309 --seq_region_end 17947928 --gap4 a.0

Translated blat (produces 8 alignments)

view_alignment --reg_conf reg_conf38 --compara compara_38 --species human --set_of_species human:chicken --alignment_type TRANSLATED_BLAT --seq_region "17" --seq_region_start 17942309 --seq_region_end 17947928 --gap4 a.0

=head2 HELP WITH GAP4

For more information on gap4, please visit the web site:

http://staden.sourceforge.net/

or click on the help button on the contig editor.

A gap4 database consists of 4 files: db_name.version, db_name.version.aux,
db_name.version.log and db_name.version.BUSY eg a.0 a.0.aux a.0.log a.0.BUSY.
If you wish to delete a gap4 database all these files should be deleted.

To exit, press the "Quit" button on each contig editor.

Useful commands in the editor are:

To view the alignment in slice coordinates, you can set a sequence to be the
reference and set it's start position to be 1 by right clicking the mouse over
the name of the species in the left hand box and selecting "Set as reference
sequence". This has the effect of ignoring padding characters. 

To highlight differences between the sequences, select "Settings" from the menubar and select "By foreground colour".

=cut

my $reg_conf;
my $dbname = "";
my $help;
my $alignment_type = "";
my $set_of_species = "";
my $species = "human";
my $method_link_species_set_id = undef;
my $seq_region = undef;
my $seq_region_start = undef;
my $seq_region_end = undef;
my $align_gab_id = undef;
my $gap4_db = undef;
my $disp_scores = undef;
my $disp_scores_old = undef;
my $disp_conservation_tags = undef;
my $disp_constrained_tags = undef;
my $disp_repeat_feature = undef;
my $disp_start_end_tags = undef;
my $template_display = 0;
my $_fofn_name = "ensembl_fofn";
my $_array_files;
my $_file_list;
my $exp_line_len = 67;


GetOptions(
    "help" => \$help,
    "reg_conf=s" => \$reg_conf,
    "compara=s" => \$dbname,
    "alignment_type=s" => \$alignment_type,
    "set_of_species=s" => \$set_of_species,
    "method_link_species_set_id=i" => \$method_link_species_set_id,
    "genomic_align_block_id=i" => \$align_gab_id,
    "species=s" => \$species,
    "seq_region=s" => \$seq_region,
    "seq_region_start=i" => \$seq_region_start,
    "seq_region_end=i" => \$seq_region_end,
     "gap4=s" => \$gap4_db,
     "display_scores" => \$disp_scores,
     "display_conservation_tags" => \$disp_conservation_tags,
     "display_constrained_element_tags" => \$disp_constrained_tags,
     "display_start_end_tags" => \$disp_start_end_tags,
     "template_display" => \$template_display,
     "repeat_feature=s" => \$disp_repeat_feature,
  );

if ($help) {
  exec("/usr/bin/env perldoc $0");
}

#Files used:
#view_alignment: a script file to set up the Staden Package environment. gap4
#must be in PATH. Calls view_alignment.pl which finds the alignments and 
#writes them as experiment files to disk and calls view_alignment.tcl which
#creates a new gap4 database, assembles the alignment sequences and brings up
#a contig editor

#if a gap4_db is defined and exists, then bring up the contig editor 
#immediately without doing any assembly. 
if (defined $gap4_db) {
    if (-e $gap4_db) {
	print "Database $gap4_db already exists. Bringing up contig editor\n";
	system "view_alignment.tcl $gap4_db [] $template_display";
	exit;
    }
}

# Configure the Bio::EnsEMBL::Registry
# Uses $reg_conf if supplied. Uses ENV{ENSMEBL_REGISTRY} instead if defined. 
# Uses ~/.ensembl_init if all the previous fail.
Bio::EnsEMBL::Registry->load_all($reg_conf);

#Getting Bio::EnsEMBL::Compara::GenomicAlignBlock object
my $genomic_align_block_adaptor = Bio::EnsEMBL::Registry->get_adaptor(
    $dbname, 'compara', 'GenomicAlignBlock');

# Getting Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object
my $method_link_species_set_adaptor = Bio::EnsEMBL::Registry->get_adaptor(
    $dbname, 'compara', 'MethodLinkSpeciesSet');

# Getting Bio::EnsEMBL::Compara::ConservationScore object
my $cs_adaptor;
if ($disp_scores || $disp_conservation_tags) { 
    $cs_adaptor = Bio::EnsEMBL::Registry->get_adaptor($dbname, 'compara', 'ConservationScore');
    throw ("No conservation scores available\n") if (!$cs_adaptor);
}
my $repeat_feature_adaptor;

#unique identifier for each sequence
my $_seq_num = 1;

#if have alignment genomic align block id
if (defined $align_gab_id) {
    my $genomic_align_block = $genomic_align_block_adaptor->fetch_by_dbID($align_gab_id);

    my $contig_num = $_seq_num;

    my $conservation_scores;
    my $constrained_blocks;
    if ($disp_scores || $disp_conservation_tags) {
	$conservation_scores = $cs_adaptor->fetch_all_by_GenomicAlignBlockId_WindowSize($genomic_align_block->dbID, 1, 0);
    }

    my $chr_start;
    my $chr_end;
    if ($disp_constrained_tags) {
	#need to find gerp method link specices set. Here assume only going to
	#be one gerp analysis
	my $cons_mlss = $method_link_species_set_adaptor->fetch_all_by_method_link_type("GERP_CONSTRAINED_ELEMENT");
	throw ("No Gerp analysis for this data\n") if (!$cons_mlss);

	#set reference genomic_align to be the first none complemented sequence
	my $gas = $genomic_align_block->get_all_GenomicAligns;
	foreach my $ga (@$gas) {
	    if ($ga->dnafrag_strand == 1) {
		$genomic_align_block->reference_genomic_align($ga);
		$genomic_align_block->reference_slice($ga->get_Slice);
		$chr_start = $ga->dnafrag_start;
		$chr_end = $ga->dnafrag_end;
		last;
	    }
	}
	$constrained_blocks = $genomic_align_block_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice($cons_mlss->[0], $genomic_align_block->reference_slice);

	#set reference genomic_align in each constrained_block to be the same
	#as the genomic_align_block reference genomic_align (see above)
	foreach my $block (@$constrained_blocks) {
	    my $c_gas = $block->get_all_GenomicAligns;
	    
	    foreach my $c_ga (@$c_gas) {
		if ($c_ga->dnafrag_id == $genomic_align_block->reference_genomic_align->dnafrag_id) {
		    $block->reference_genomic_align($c_ga);
		}
	    }
	}
    }

    writeExperimentFiles($genomic_align_block, 0, $genomic_align_block->length, $chr_start, $chr_end, $contig_num, 1, $conservation_scores, $constrained_blocks);

    open (FOFN, ">$_fofn_name") || die "ERROR writing ($_fofn_name) file\n";
    print FOFN "$_file_list";
    close (FOFN);
    
    if (!defined $gap4_db) {
	$gap4_db = "gap4_compara_" . $genomic_align_block->dbID . ".0";
    }

    system "view_alignment.tcl $gap4_db $_fofn_name $template_display";

    #remove experiment files
    unlink @$_array_files;
    #remove file of filenames
    unlink $_fofn_name;
    exit;
}


# Getting all the Bio::EnsEMBL::Compara::GenomeDB objects
my $genome_db_adaptor = Bio::EnsEMBL::Registry->get_adaptor($dbname, 'compara', 'GenomeDB');
throw("Registry configuration file has no data for connecting to <$dbname>")
    if (!$genome_db_adaptor);

my $genome_dbs;
foreach my $this_species (split(":", $set_of_species)) {

    my $this_meta_container_adaptor = Bio::EnsEMBL::Registry->get_adaptor(
									  $this_species, 'core', 'MetaContainer');
    throw("Registry configuration file has no data for connecting to <$this_species>")
	if (!$this_meta_container_adaptor);
    my $this_binomial_id = $this_meta_container_adaptor->get_Species->binomial;

    # Fetch Bio::EnsEMBL::Compara::GenomeDB object    
    my $genome_db = $genome_db_adaptor->fetch_by_name_assembly($this_binomial_id);

    # Add Bio::EnsEMBL::Compara::GenomeDB object to the list
    push(@$genome_dbs, $genome_db);
}

#Find from species and alignment type
my $method_link_species_set;
if (!defined $method_link_species_set_id) {
    $method_link_species_set = $method_link_species_set_adaptor->fetch_by_method_link_type_GenomeDBs($alignment_type, $genome_dbs);
    throw("The database do not contain any $alignment_type data for $set_of_species!")
    if (!$method_link_species_set);
} else {
   $method_link_species_set = $method_link_species_set_adaptor->fetch_by_dbID($method_link_species_set_id);
    throw("The database do not contain any data for method link species set id $method_link_species_set_id!")
    if (!$method_link_species_set);
}

#Fetching slice for species
my $slice;
my $genomic_align_blocks;
my $slice_adaptor;

if ($seq_region) {
    $slice_adaptor = Bio::EnsEMBL::Registry->get_adaptor($species, 'core', 'Slice');
    throw("Registry configuration file has no data for connecting to <$species>") if (!$slice_adaptor);

    throw ("Must define seq_region_start and seq_region_end") if (!$seq_region_start || !$seq_region_end);

    $slice = $slice_adaptor->fetch_by_region('toplevel', $seq_region, $seq_region_start, $seq_region_end);
	throw("No Slice can be created with coordinates $seq_region:$seq_region_start-$seq_region_end") if (!$slice);

    # Fetching all the GenomicAlignBlock corresponding to this Slice:
    $genomic_align_blocks =
	$genomic_align_block_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice($method_link_species_set, $slice);
} else {
    throw ("Either a genomic_align_block_id or a seq_region must be defined");
}

if (scalar(@$genomic_align_blocks) == 0) {
    throw ("No genomic align blocks found\n");
    
}

#write experiment files for each alignment found
foreach my $genomic_align_block (@$genomic_align_blocks) { 
    my $contig_num = $_seq_num; 

    my $genomic_align = $genomic_align_block->reference_genomic_align;

    #find start and end of alignment 
    my $chr_start = $genomic_align->dnafrag_start;
    my $chr_end = $genomic_align->dnafrag_end;

    if ($slice->start > $genomic_align->dnafrag_start) {
	$chr_start = $slice->start;
    }
    if ($slice->end < $genomic_align->dnafrag_end) {
	$chr_end = $slice->end;
    }

    my $conservation_scores;
    if ($disp_scores || $disp_conservation_tags) {
	$conservation_scores = $cs_adaptor->fetch_all_by_GenomicAlignBlock($genomic_align_block, $genomic_align_block->length, "MAX", 1);
    }
    my $constrained_blocks;
    if ($disp_constrained_tags) {
	my $cons_mlss = $method_link_species_set_adaptor->fetch_by_method_link_type_GenomeDBs("GERP_CONSTRAINED_ELEMENT", $genome_dbs);
	throw ("No Gerp analysis for this data\n") if (!$cons_mlss);

	my $gab_slice = $slice_adaptor->fetch_by_region('toplevel', $seq_region, $chr_start, $chr_end);

	#need to restrict to current genomic_align_block region since $slice
	#may extend over several genomic_align_blocks
	$constrained_blocks = $genomic_align_block_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice($cons_mlss, $gab_slice);

    }

    #Convert chromosome position into alignment position
    my $start;
    my $end;
    #need this to add deletions at the beginning

    if ($chr_start == $genomic_align->dnafrag_start) {
	$start = 1;
    } else {
	$start = findAlignPos($chr_start, $genomic_align->dnafrag_start, 
				 $genomic_align->cigar_line);
    } 
    if ($chr_end == $genomic_align->dnafrag_end) {
	$end = $genomic_align_block->length;
    } else {
	$end = findAlignPos($chr_end, $genomic_align->dnafrag_start, 
			       $genomic_align->cigar_line);
    }
    writeExperimentFiles($genomic_align_block, $start-1, ($end-$start+1), 
			 $chr_start, $chr_end, $contig_num, 1, 
			 $conservation_scores, $constrained_blocks);
}

open (FOFN, ">$_fofn_name") || die "ERROR writing ($_fofn_name) file\n";
print FOFN "$_file_list";
close (FOFN);

if (!defined $gap4_db) {
    $gap4_db = "gap4_compara_" . $seq_region . "_" . $seq_region_start . "_" . $seq_region_end . ".0";
}

#call tcl interface to gap4 to create a gap4 database and bring up a contig
#editor for each genomic_align_block
system "view_alignment.tcl $gap4_db $_fofn_name $template_display";

#remove experiment files
unlink @$_array_files;
#remove file of filenames
unlink $_fofn_name;


sub getRepeatFeatures {
    my ($disp_repeat_feature, $slice, $species, $dnafrag_start, $cigar_line, $FILE) = @_;

    $repeat_feature_adaptor = Bio::EnsEMBL::Registry->get_adaptor($species, 'core', 'RepeatFeature');
    throw("Registry configuration file has no data for connecting to <$species>")
	if (!$repeat_feature_adaptor);

    my $repeat_features = $repeat_feature_adaptor->fetch_all_by_Slice($slice);
    my $cnt = 0;
    foreach my $repeat_feature (@$repeat_features) {
	my $name = $repeat_feature->repeat_consensus->name;
	if ($name =~ /^$disp_repeat_feature$/) {		
	    my $start = findAlignPos($repeat_feature->start, 1, $cigar_line);
	    my $end = findAlignPos($repeat_feature->end, 1, $cigar_line);

	    #print "$species start $start " . $repeat_feature->start . " end $end " . $repeat_feature->end . " strand " . $repeat_feature->strand . " score " . $repeat_feature->score . " seq " . $repeat_feature->seq . "\n";
	    $name .= " length=" .  $repeat_feature->length . " strand=" .$repeat_feature->strand; 
	    if ($repeat_feature->strand == 1) {
		print $FILE "TG   COMM + $start..$end $name \n"; 
	    } else {
		print $FILE "TG   OLIG + $start..$end $name \n"; 
	    }
	    $cnt++;
	}
    }
}

#convert from chromosome coords to alignment coords
#returns $chr_pos in alignment coords
sub findAlignPos {
    my ($chr_pos, $total_chr_pos, $cigar_line) = @_;

    my @cig = ( $cigar_line =~ /(\d*[GMD])/g );

    my $i = 0;

    my ($cigType, $cigLength);
    my $total_pos = 0;
    my $align_pos;
    
    #convert chr_pos into alignment coords
    while ($total_chr_pos <= $chr_pos) {
	my $cigElem = $cig[$i++];
	$cigType = substr( $cigElem, -1, 1 );
	$cigLength = substr( $cigElem, 0 ,-1 );
	$cigLength = 1 unless ($cigLength =~ /^\d+$/);

	$total_pos += $cigLength;
	if( $cigType eq "M" ) {
	    $total_chr_pos += $cigLength;
	}

    }
    my $start_offset = $total_chr_pos - $chr_pos;
    if ($cigType eq "M") {
	$align_pos = $total_pos - $start_offset + 1;
    }
    return $align_pos;
}

#write out genomic_align sequences as Staden experiment files
sub writeExperimentFiles {
    my ($gab, $align_start, $length, $chr_start, $chr_end, $contig_num, $new_contig, $conservation_scores, $constrained_blocks) = @_;
    my $exp_seqs = "";
    my $done_disp_scores = 0;
    my $done_tags = 0;
    my $done_constrained_tags = 0;

    #create mfa file of multiple alignment from genomic align block
    foreach my $genomic_align (@{$gab->get_all_GenomicAligns}) {
	my $filename = "ensembl_$_seq_num" . ".exp";
	
	my $aligned_sequence = substr $genomic_align->aligned_sequence, $align_start, $length;

	$aligned_sequence =~ tr/-/*/;
	$aligned_sequence =~ s/(.{60})/$1\n/g;
	$aligned_sequence =~ s/(.*)/     $1/g;

	open (EXP, ">$filename") || die "ERROR writing ($filename) file\n";

	my $name = $genomic_align->genome_db->name;
	$name =~ tr/ /_/;
	if ($new_contig) {
	    $contig_num = $name . "_" . $_seq_num;
	}
	print EXP "ID   " . $name . "_$_seq_num\n";
	if ($new_contig) {
	    print EXP "AP   *new* + 0 0\n"
	} else {
	    print EXP "AP   $contig_num + 0 0\n";
	}

	#write out regions of called conservation scores
	if ($disp_conservation_tags && !$done_tags) {
	    $done_tags = 1;
	    my $end_pos = 0;
	    my $start_pos = 0;
	    #foreach my $cons_score (@$conservation_scores) {
	    for (my $j = $align_start; $j < $align_start+$length; $j++) {
		if (!$start_pos && $conservation_scores->[$j]->diff_score != 0) {
		    $start_pos = $conservation_scores->[$j]->position - $align_start;
		    $end_pos = 0;
		}
		if (!$end_pos && $conservation_scores->[$j]->diff_score == 0) {
		    $end_pos = $conservation_scores->[$j]->position-1 - $align_start;
		    print EXP "TC   COMM + $start_pos..$end_pos\n";
		    $start_pos = 0;
		}
	    }
		
	    $end_pos = scalar(@$conservation_scores);
	    print EXP "TC   COMM + $start_pos..$end_pos\n";
	}

	#write out constrained element tags
	if ($disp_constrained_tags && !$done_constrained_tags) {
	    $done_constrained_tags = 1;
	    foreach my $block (@$constrained_blocks) { 

		my ($start, $end);
		if ($chr_start > $block->reference_genomic_align->dnafrag_start) {
		    $start = $chr_start;
		} else {
		    $start = $block->reference_genomic_align->dnafrag_start;
		}
		if ($chr_end < $block->reference_genomic_align->dnafrag_end) {
		    $end = $chr_end;
		} else {
		    $end = $block->reference_genomic_align->dnafrag_end;
		}

		#no assumptions on order so findAlignPos starts again each
		#time. Maybe a way to speed this up?
		my $ref_start = findAlignPos($start, $gab->reference_genomic_align->dnafrag_start, $gab->reference_genomic_align->cigar_line) - $align_start;
		my $ref_end = findAlignPos($end, $gab->reference_genomic_align->dnafrag_start,$gab->reference_genomic_align->cigar_line) - $align_start;

		printf EXP "TC   COMM + %d..%d score=%.3f\n", $ref_start, $ref_end, $block->score;
	    }
	}

	#write out conservation scores
	if ($disp_scores && !$done_disp_scores) {
	    $done_disp_scores = 1;
	    my $i = 1;
	    print STDOUT "\n***Displaying conservation scores may take a few minutes***\n";
	    for (my $j = $align_start; $j < $align_start+$length; $j++) {
		if ($conservation_scores->[$j]->diff_score != 0) {
		    printf(EXP "TC   COMM + %d..%d score=%.3f\n", $i, $i, $conservation_scores->[$j]->diff_score);
		}
		$i++;
	    }
	}

	if (defined $disp_repeat_feature) {
	    getRepeatFeatures($disp_repeat_feature, $genomic_align->get_Slice, $genomic_align->dnafrag->genome_db->name, $genomic_align->dnafrag_start, $genomic_align->cigar_line, \*EXP);
	}

	if ($disp_start_end_tags) {
	    writeStartEndTags($genomic_align,\*EXP); 
	}

	#write out sequence
	print EXP "SQ\n";
	print EXP "$aligned_sequence\n";
	print EXP "//";
	close(EXP);
	$_file_list .= "$filename\n";
	push @$_array_files, $filename;
	$_seq_num++;
	$new_contig = 0;

    }
}

sub writeStartEndTags {
    my ($genomic_align, $FILE) = @_;

    my $start = findAlignPos($genomic_align->dnafrag_start, 
			     $genomic_align->dnafrag_start, 
			     $genomic_align->cigar_line);
    my $end = findAlignPos($genomic_align->dnafrag_end, 
			   $genomic_align->dnafrag_start, 
			   $genomic_align->cigar_line);

    print $FILE "TG   STOP + $start..$start \n"; 
    print $FILE "TG   STOP + $end..$end \n"; 
}
