#!/software/bin/perl -w

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

This script downloads alignments from a compara database, creates a gap4
database and brings up a contig editor for each alignment block found. This
allows the alignment to be scrolled and viewed in detail. Additional 
information such as genes, conserved regions and repeats can be highlighted.

=head1 SETUP

The location of the Staden Package and view_alignment must be in your path.
For example:

in bash:

export PATH=/nfs/sids/badger/OSF/STADEN_PKGS/unix-rel-1-7-0/linux-x86_64-bin:$HOME/src/ensembl_main/ensembl_compara/scripts/view_alignment:$PATH

in csh:

setenv PATH /nfs/sids/badger/OSF/STADEN_PKGS/unix-rel-1-7-0/linux-x86_64-bin:$HOME/src/ensembl_main/ensembl_compara/scripts/view_alignment:$PATH

It must also be run under X windows.

=head1 SYNPOSIS

view_alignment --help

view_alignment 
    [--mfa_file multi fasta file]
    [--reg_conf registry_configuration_file]
    [--dbname compara_database]
    [--alignment_type alignment_type]
    [--set_of_species species1:species2:species3...]
    [--method_link_species_set_id method_link_species_set_id]
    [--genomic_align_block_id genomic_align_block_id]
    [--species species]
    [--seq_region seq_region]
    [--seq_region_start start]
    [--seq_region_end end]
    [--gap4 gap4_database]
    [--display_scores]
    [--display_constrained_element_tags]
    [--display_exon_tags]
    [--display_gene_tags]
    [--display_start_end_tags]
    [--template_display]
    [--repeat_feature repeat1:repeat2:repeat3]
    [--file_of_repeat_feature file containing list of repeat features]
    
=head1 OPTIONS

=head2 GETTING HELP

=over

=item B<[--help]>

  Prints help message and exits.

=back

=head2 CONFIGURATION

=over

=item B<[--mfa_file multi fasta file]>

Display the alignment from a multi fasta file. No other arguments required.

=item B<[--reg_conf registry_configuration_file]>

The Bio::EnsEMBL::Registry configuration file. If none is given,
the one set in ENSEMBL_REGISTRY will be used if defined, if not
~/.ensembl_init will be used.

=item B<--dbname compara_db_name_or_alias>

The compara database to query. You can use either the original name or any of 
the aliases given in the registry_configuration_file. 

=item B<[--alignment_type]>

This should be an exisiting method_link_type eg PECAN, TRANSLATED_BLAT, BLASTZ_NET

=item B<[--set_of_species]>

The set of species used in the alignment. These should be the same as defined 
in the registry configuration file aliases. The species should be separated by 
a colon e.g. human:rat

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

=item B<[--display_constrained_element_tags]>

Tags (shown as coloured blocks in the contig editor) are created showing the
position of constrained elements (conserved regions) and their 'rejected
substitution' score. Only valid if conservation scores have been calculated for
the alignment. The tag is of type "COMM", colour blue and is shown on the "consensus line".

=item B<[--display_scores]>

A tag (shown as a coloured block in the contig editor) is created for each 
base that has a conservation value and shows the conservation score. This can 
produce a lot of tags which can take a long time to be read in. Only valid if 
conservation scores have been calculated for the alignment. The tag is of type 
"COMP", colour red.

=item B<[--display_start_end_tags]>

This options tags the first and last base of each species in the alignment
with a tag type of "STOP" (default colour pale blue).

=item B<[--template_display]>

Automatically bring up a template display. Useful for looking at an overall 
view of tags

=item B<[--repeat_feature]>

Valid repeat feature name eg "MIR".
Tags (shown as coloured blocks in the contig editor) are created for each 
repeat found. Repeats on the forward strand assigned a tag type of "COMM" 
(default colour is blue) and repeats on the reverse strand have tag type
"OLIGO" (default colour is yellow). The repeats should be separated by a colon.

=item B<[--file_of_repeat_feature]>

A file containing a list of valid repeat feature names eg "MIR".
Tags (shown as coloured blocks in the contig editor) are created for each 
repeat found. Repeats on the forward strand assigned a tag type of "COMM" 
(default colour is blue) and repeats on the reverse strand have tag type
"OLIGO" (default colour is yellow).

=item B<[--display_exon_tags]>

Tags (shown as coloured blocks in the contig editor) are created showing the
position of coding exons. The tag is of type "REPT", colour green for exons on the forward strand and type "ALUS", colour bright green for exons on the reverse strand.

=item B<[--display_gene_tags]>

Tags (shown as coloured blocks in the contig editor) are created showing the
position of genes. The tag is of type "REPT", colour green.

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

Using species and alignment type, creating a database called a.0:

view_alignment --reg_conf reg_conf47 --dbname compara_47 --species human --set_of_species human:mouse:rat:dog:chicken:cow:opossum:rhesus:chimp:platypus --alignment_type PECAN --seq_region "17" --seq_region_start 37220641 --seq_region_end 37247904 --gap4 a.0

Using method_link_species_set_id:

view_alignment --reg_conf reg_conf47 --dbname compara_47 --species human --method_link_species_set_id 292 --seq_region "17" --seq_region_start 37220641 --seq_region_end 37247904 --gap4 a.0

Using alignment genomic align block id:

view_alignment --reg_conf reg_conf47 --dbname compara_47 --genomic_align_block_id 2920000011644 --gap4 a.0

Tag coding exons and constrained elements and bring up the template display:

view_alignment --reg_conf reg_conf47 --dbname compara_47 --species human --set_of_species human:mouse:rat:dog:chicken:cow:opossum:rhesus:chimp:platypus --alignment_type PECAN --seq_region "17" --seq_region_start 37222810 --seq_region_end 37233000 --gap4 a.0 --display_exon_tags --display_constrained_element_tags --template_display

Tag conservation scores (small region only)

view_alignment --reg_conf reg_conf47 --dbname compara_47 --species human --set_of_species human:mouse:rat:dog:chicken:cow:opossum:rhesus:chimp:platypus --alignment_type PECAN --seq_region "17" --seq_region_start 37222810 --seq_region_end 37222900 --gap4 a.0 --display_scores

Tag repeat features

view_alignment --reg_conf reg_conf47 --dbname compara_47 --species human --set_of_species human:mouse:rat:dog:chicken:cow:opossum:rhesus:chimp:platypus --alignment_type PECAN --seq_region "17" --seq_region_start 37222810 --seq_region_end 37233000 --gap4 a.0 --file_of_repeat_feature transposonsII.txt

Blastz_net alignment (produces 9 alignments)

view_alignment --reg_conf reg_conf47 --dbname compara_47 --species human --set_of_species human:mouse --alignment_type BLASTZ_NET --seq_region "17" --seq_region_start 37222810 --seq_region_end 37233000 --gap4 a.0

=head2 HELP WITH GAP4

For more information on gap4, please visit the web site:

http://staden.sourceforge.net/

or click on the help button on the contig editor.

To remove the contig editor, press the "Quit" button.

Useful commands in the editor are:

To view the alignment in slice coordinates, you can set a sequence to be the
reference and set its start position to be 1 by right clicking the mouse over
the name of the species in the left hand box and selecting "Set as reference
sequence". This has the effect of ignoring padding characters. 

To highlight differences between the sequences, select "Settings" from the menubar and select "Highlight Disagreements".

Tidying up:

A gap4 database consists of 4 files: db_name.version, db_name.version.aux,
db_name.version.log and db_name.version.BUSY eg a.0 a.0.aux a.0.log a.0.BUSY.
If you wish to delete a gap4 database all these files should be deleted.

=cut

my $reg_conf;
my $dbname = "";
my $help;
my $alignment_type = "";
my $set_of_species = "";
my $species;
my $method_link_species_set_id = undef;
my $seq_region = undef;
my $seq_region_start = undef;
my $seq_region_end = undef;
my $align_gab_id = undef;
my $gap4_db = undef;
my $disp_conservation_scores = undef;
my $disp_constrained_tags = undef;
my $set_of_repeat_features = undef;
my $file_of_repeat_features = undef;
my $disp_start_end_tags = undef;
my $disp_exon_tags = undef;
my $disp_gene_tags = undef;
my $template_display = 0;
my $_fofn_name = "ensembl_fofn";
my $_array_files;
my $_file_list;
my $exp_line_len = 67;
my $mfa_file;

GetOptions(
    "help" => \$help,
    "reg_conf=s" => \$reg_conf,
    "dbname=s" => \$dbname,
    "alignment_type=s" => \$alignment_type,
    "set_of_species=s" => \$set_of_species,
    "method_link_species_set_id|mlss=i" => \$method_link_species_set_id,
    "genomic_align_block_id=i" => \$align_gab_id,
    "species=s" => \$species,
    "seq_region=s" => \$seq_region,
    "seq_region_start=i" => \$seq_region_start,
    "seq_region_end=i" => \$seq_region_end,
     "gap4=s" => \$gap4_db,
     "display_scores" => \$disp_conservation_scores,
     "display_constrained_element_tags" => \$disp_constrained_tags,
     "display_exon_tags" => \$disp_exon_tags,
     "display_gene_tags" => \$disp_gene_tags,
     "display_start_end_tags" => \$disp_start_end_tags,
     "template_display" => \$template_display,
     "repeat_feature=s" => \$set_of_repeat_features,
     "file_of_repeat_feature=s" => \$file_of_repeat_features,
     "mfa_file=s" => \$mfa_file,
  );

if ($help) {
  exec("/usr/bin/env perldoc $0");
}

#if a gap4_db is defined and exists, then bring up the contig editor 
#immediately without doing any assembly. 
if (defined $gap4_db) {
    if (-e $gap4_db) {
	print "Database $gap4_db already exists. Bringing up contig editor\n";
	system "view_alignment.tcl $gap4_db [] $template_display";
	exit;
    }
}

my $reg = "Bio::EnsEMBL::Registry";

$reg->no_version_check(1);

# Configure the Bio::EnsEMBL::Registry
# Uses $reg_conf if supplied. Uses ENV{ENSMEBL_REGISTRY} instead if defined. 
# Uses ~/.ensembl_init if all the previous fail.
$reg->load_all($reg_conf);

#Load in alignment from multi fasta file
if (defined $mfa_file) {

    load_multi_fasta_file($mfa_file);
    exit;
}

#Getting Bio::EnsEMBL::Compara::GenomicAlignBlock object
my $genomic_align_block_adaptor = $reg->get_adaptor(
				  $dbname, 'compara', 'GenomicAlignBlock');
throw ("No genomic_align_blocks") if (!$genomic_align_block_adaptor);

# Getting Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object
my $method_link_species_set_adaptor = $reg->get_adaptor(
    $dbname, 'compara', 'MethodLinkSpeciesSet');
throw ("No method_link_species_se") if (!$method_link_species_set_adaptor);

my $align_slice_adaptor = $reg->get_adaptor($dbname, 'compara', 'AlignSlice');
throw ("No align_slice") if (!$align_slice_adaptor);

# Getting Bio::EnsEMBL::Compara::ConservationScore object
my $cs_adaptor;
if ($disp_conservation_scores) { 
    $cs_adaptor = $reg->get_adaptor($dbname, 'compara', 'ConservationScore');
    throw ("No conservation scores available\n") if (!$cs_adaptor);
}

my $repeat_feature_adaptor;

#unique identifier for each sequence
my $_seq_num = 1;

#if have alignment genomic align block id
if (defined $align_gab_id) {
    my $genomic_align_block = $genomic_align_block_adaptor->fetch_by_dbID($align_gab_id);

    throw ("Invalid genomic_align_block_id") if (!$genomic_align_block);

    my $contig_num = $_seq_num;

    #if $species is set, use that as reference genomic align else used first 
    my $gas = $genomic_align_block->get_all_GenomicAligns;
    if (defined $species) {
	my $this_meta_container_adaptor = $reg->get_adaptor(
					  $species, 'core', 'MetaContainer');
	throw("Registry configuration file has no data for connecting to <$species>")
	    if (!$this_meta_container_adaptor);
	my $species_name = $this_meta_container_adaptor->get_Species->binomial;
	foreach my $ga (@$gas) {
	    if ($ga->dnafrag->genome_db->name eq $species_name) {
		$genomic_align_block->reference_genomic_align($ga);
	    }
	}
    } else {
	#set first ga as reference. Complement if necessary
	$genomic_align_block->reference_genomic_align($gas->[0]);
    }

    if (defined($genomic_align_block->reference_genomic_align) && $genomic_align_block->reference_genomic_align->dnafrag_strand == -1) {
	$genomic_align_block->reverse_complement();
    }

    my $align_slice = $align_slice_adaptor->fetch_by_GenomicAlignBlock($genomic_align_block, 1);
    writeExperimentFiles($genomic_align_block, $align_slice, $contig_num, 1);

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
my $genome_db_adaptor = $reg->get_adaptor($dbname, 'compara', 'GenomeDB');
throw("Registry configuration file has no data for connecting to <$dbname>")
    if (!$genome_db_adaptor);

my $genome_dbs;
foreach my $this_species (split(":", $set_of_species)) {
    my $genome_db = $genome_db_adaptor->fetch_by_registry_name($this_species);

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
    $slice_adaptor = $reg->get_adaptor($species, 'core', 'Slice');
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

#write experiment files for each alignment found
foreach my $genomic_align_block (@$genomic_align_blocks) { 
    my $contig_num = $_seq_num; 

    print "GAB " . $genomic_align_block->dbID . "\n";

    my $genomic_align = $genomic_align_block->reference_genomic_align;

    my $restricted_gab = $genomic_align_block->restrict_between_reference_positions($slice->start, $slice->end, $genomic_align);

    my $restricted_ga = $restricted_gab->reference_genomic_align;

    #don't use restricted gab here because this causes problems elsewhere
    #since the new gab doesn't retain all the information of the original gab
    #such as original strand
    #my $align_slice = $align_slice_adaptor->fetch_by_Slice_MethodLinkSpeciesSet($slice, $method_link_species_set, 1);
    my $align_slice = $align_slice_adaptor->fetch_by_Slice_MethodLinkSpeciesSet($restricted_ga->get_Slice, $method_link_species_set, 1);

    writeExperimentFiles($restricted_gab, $align_slice, $contig_num, 1);
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


sub writeExperimentFiles {
    my ($gab, $align_slice, $contig_num, $new_contig) = @_;
    my $done_constrained_tags = 0;
    my $done_conservation_scores = 0;

    my $repeat_feature_list;
    if (defined $set_of_repeat_features) {
	foreach my $repeat (split(":", $set_of_repeat_features)) {	
	    $repeat_feature_list->{lc($repeat)} = 1;
	}
    }
    if (defined $file_of_repeat_features) {
	open FILE, "< $file_of_repeat_features" or die "Can't open file $file_of_repeat_features: $!\n";
	while (<FILE>) {
	    my $line = $_;
	    chomp $line;
	    $repeat_feature_list->{lc($line)} = 1;
	}
	close FILE;
    }

    #create mfa file of multiple alignment from genomic align block
    foreach my $genomic_align (@{$gab->get_all_GenomicAligns}) {

	#hack to remove takifugu!
	#if ($genomic_align->genome_db->name eq "takifugu") {
	    #next;
	#}

	my $filename = "ensembl_$_seq_num" . ".exp";

	my $aligned_sequence = $genomic_align->aligned_sequence;

	#print "name " . $genomic_align->genome_db->name . " " . $genomic_align->dnafrag->name . " start " . $genomic_align->dnafrag_start . " end " . $genomic_align->dnafrag_end . " " . $aligned_sequence . "\n";

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
	    print EXP "AP   *new* + 0 0\n";
	} else {
	    print EXP "AP   $contig_num + 0 0\n";
	}

	#write gene tags
	if (defined $disp_gene_tags) {
	    my $slice = $genomic_align->get_Slice;
	    foreach my $gene (@{$slice->get_all_Genes}) {
		my $g_start = $gene->start;
		my $g_end = $gene->end;
		if ($gene->start < 1) {
		    $g_start = 1;
		}
		if ($gene->end > ($slice->end-$slice->start+1)) {
		    $g_end = ($slice->end-$slice->start+1);
		}

		#convert into alignment coords
		my $gene_start = findAlignPos($g_start, 1, $genomic_align->cigar_line);
		my $gene_end = findAlignPos($g_end, 1, $genomic_align->cigar_line);
		printf(EXP "TG   REPT + %d..%d gene %s %s:%d-%d\n", $gene_start, $gene_end, $gene->display_id, $genomic_align->dnafrag->name, $gene->start + $slice->start, $gene->end + $slice->start);
	    }
	}

	#write exon tags
	if (defined $disp_exon_tags) {
	    #my $min_length = 57;
	    my $min_length = 1;
	    my $slice = $genomic_align->get_Slice;
	    my $exon_array = getCodingExons($slice, $min_length);
	    foreach my $exon (@$exon_array) {

		#trim exon at start and end of slice
		my $e_start = $exon->start;
		my $e_end = $exon->end;
		if ($exon->start < 1) {
		    $e_start = 1;
		}
		if ($exon->end > ($slice->end-$slice->start+1)) {
		    $e_end = ($slice->end-$slice->start+1);
		}

		#convert into alignment coords
		my $exon_start = findAlignPos($e_start, 1, $genomic_align->cigar_line);
		my $exon_end = findAlignPos($e_end, 1, $genomic_align->cigar_line);
		if ($exon->strand == 1) {
		    printf(EXP "TG   REPT + %d..%d exon %s:%d-%d\n", $exon_start, $exon_end, $genomic_align->dnafrag->name, $exon->start + $slice->start, $exon->end + $slice->start);
		} else {
		    printf(EXP "TG   ALUS + %d..%d exon %s:%d-%d\n", $exon_start, $exon_end, $genomic_align->dnafrag->name, $exon->start + $slice->start, $exon->end + $slice->start);
		}
	    }
	}

	#write constrained element tags
	#only do once (written on consensus)
	if ($disp_constrained_tags && $genomic_align == $gab->reference_genomic_align) {
	    writeConstrainedBlocks($align_slice, $gab->length, \*EXP);	    
	}

	#write conservation score tags
	#only do once (written on consensus)
	if ($disp_conservation_scores && $genomic_align == $gab->reference_genomic_align) {
	    writeConservationScores($align_slice, \*EXP);	    
	}

	#write repeat feature tags
	if (defined $set_of_repeat_features || defined $file_of_repeat_features) {
	    foreach my $a_slice (@{$align_slice->get_all_Slices}) {
		my $original_feature = $a_slice->get_all_underlying_Slices($a_slice->start, $a_slice->end)->[0];

		#need to find the current genomic_align in the align_slice list.
		if ($a_slice->genome_db->name eq $genomic_align->genome_db->name && $original_feature->seq_region_name eq $genomic_align->dnafrag->name && $original_feature->start == $genomic_align->dnafrag_start && $original_feature->end == $genomic_align->dnafrag_end) {

		    writeRepeatFeatures($a_slice, $gab->length, $repeat_feature_list, \*EXP);
		}
	    }
	}

	#write start/end tags
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

#return all coding exons in slice above min_length
sub getCodingExons {
    my ($slice, $min_length) = @_;

    if (!defined $min_length) {
	$min_length = 1;
    }

    my @exons;
    my $gene_cnt = 0;
    my $trans_cnt = 0;
    foreach my $gene (@{$slice->get_all_Genes}) {
	#only select protein coding exons
	if (lc($gene->biotype) eq "protein_coding") {
	    
	    #get transcripts
	    foreach my $trans (@{$gene->get_all_Transcripts}) {
		
		#get translated exons with start and end exons truncated to 
		#CDS regions
		foreach my $exon (@{$trans->get_all_translateable_Exons}) {
		    unless (defined $exon->stable_id) {
			warn("COREDB error: does not contain exon stable id for translation_id ".$exon->dbID."\n");
			next;
		    }
		    #only store exons of at least $min_length
		    if (($exon->end - $exon->start + 1) >= $min_length) {
			if ($exon->end >= 1 && $exon->start <= ($slice->end-$slice->start+1)) {
			    push @exons, $exon;
			}
		    }
		}
	    }
	}
    }
    
    my $exon_array = [sort {$a->start <=> $b->start} @exons];
    return $exon_array;
}

#add COMM tag on the consensus for each constrained element.
sub writeConstrainedBlocks {
    my ($align_slice, $length, $FILE) = @_;

    my $cons_elems = $align_slice->get_all_constrained_elements();

    foreach my $cons_elem (@$cons_elems) {
	#printf("TC   COMM + %d..%d Constrained element score=%d\n", 
	 #      $cons_elem->reference_slice_start, 
	  #     $cons_elem->reference_slice_end, 
	   #    $cons_elem->score);
	printf($FILE "TC   COMM + %d..%d Constrained element score=%d\n", 
	       $cons_elem->reference_slice_start, 
	       $cons_elem->reference_slice_end, 
	       $cons_elem->score);
    }
}

#add COMM tag on each base on the consensus. Use with care! Can take a long
#time
sub writeConservationScores {
    my ($align_slice, $FILE) = @_;

    my $cons_scores = $align_slice->get_all_ConservationScores($align_slice->get_all_Slices()->[0]->length, "MAX", 1);

    my $i;
    foreach my $cons_score (@$cons_scores) {
	if ($cons_score->diff_score) {
	    $i = $cons_score->position;
	    printf($FILE "TC   COMP + %d..%d score=%.3f\n", $i, $i, $cons_score->diff_score);
	    
	}
	$i++;
    }
}

#add COMM (forward) or OLIG (reverse) tags on each species for repeat features 
#in repeat_feature_list
sub writeRepeatFeatures {
    my ($a_slice, $gab_length, $repeat_feature_list, $FILE) = @_;

    my $repeat_features = $a_slice->get_all_RepeatFeatures;
    foreach my $repeat_feature (@$repeat_features) {
	my $name = $repeat_feature->repeat_consensus->name;
	if ($repeat_feature_list->{lc($name)}) {
	    $name .= " length=" .  $repeat_feature->length . " strand=" .$repeat_feature->strand . " score= " . $repeat_feature->score . " hstart " . $repeat_feature->hstart . " hend " . $repeat_feature->hend; 
	    my $start = $repeat_feature->start;
	    if ($start < 1) {
		$start = 1;
	    }
	    my $end = $repeat_feature->end;
	    if ($end > $gab_length) {
		$end = $gab_length;
	    }
	    if ($repeat_feature->strand == 1) {
		printf($FILE "TG   COMM + %d..%d %s\n", $start, $end, $name); 
	    } else {
		printf($FILE "TG   OLIG + %d..%d %s\n", $start, $end, $name); 
	    }
	}
    }
}

#add a STOP tag to the first and last base of each genomic_align. Useful if 
#trying to find the first and last base of a sequence!
sub writeStartEndTags {
    my ($genomic_align, $FILE) = @_;

    my $start = findAlignPos($genomic_align->dnafrag_start, 
			     $genomic_align->dnafrag_start, 
			     $genomic_align->cigar_line);
    my $end = findAlignPos($genomic_align->dnafrag_end, 
			   $genomic_align->dnafrag_start, 
			   $genomic_align->cigar_line);

    print $FILE "TG   STOP + $start..$start Start\n"; 
    print $FILE "TG   STOP + $end..$end End\n"; 
}

sub load_multi_fasta_file {
    my ($mfa_file) = @_;

    my $exp_name;
    my $new_contig = 1;
    my $contig_num;

    open FILE, "< $mfa_file" or die "Can't open file $mfa_file: $!\n";
    while (<FILE>) {
	my $line = $_;
	chomp $line;
	#ignore comments
	next if ($line =~ /^;/);
	if ($line =~ /^>/) {
	    $line =~ tr/>//d;
	    if (defined $exp_name){
		print EXP "//\n";
		close (EXP);
		push @$_array_files, $exp_name;
		$_file_list .= "$exp_name\n";
	    }
	    $exp_name = $line . ".exp";
	    open (EXP, ">$exp_name") || die "ERROR writing ($exp_name) file\n";
	    print EXP "ID   $line\n";

	    if ($new_contig) { 
		print EXP "AP   *new* + 0 0\n";
		$contig_num = $line;
		$new_contig = 0;
	    } else {
		print EXP "AP   $contig_num + 0 0\n";
	    }
	    print EXP "SQ\n";
	    print "Creating $exp_name\n";
	    
	} else {
	    $line =~ tr/-/*/;
	    print EXP "     $line\n"; 
	}
    }
    print EXP "//\n";
    close (EXP);
    push @$_array_files, $exp_name;
    $_file_list .= "$exp_name\n";

    open (FOFN, ">$_fofn_name") || die "ERROR writing ($_fofn_name) file\n";
    print FOFN "$_file_list";
    close (FOFN);
    
    if (!defined $gap4_db) {
	$gap4_db = "gap4_compara_" . $mfa_file . ".0";
    }

    system "view_alignment.tcl $gap4_db $_fofn_name $template_display";

    #remove experiment files
    unlink @$_array_files;
    #remove file of filenames
    unlink $_fofn_name;
}
