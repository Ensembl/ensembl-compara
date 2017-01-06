#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2017] EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


use strict;
use warnings;

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Utils::Exception qw(throw);
use Getopt::Long;


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

view_alignment

=head1 DESCRIPTION

This script downloads alignments from a compara database, creates a gap4
database and brings up a contig editor for each alignment block found. This
allows the alignment to be scrolled and viewed in detail. Additional 
information such as genes, conserved regions and repeats can be highlighted.

=head1 SETUP

The location of view_alignment must be in your path.
For example:

in bash:

export PATH=$HOME/src/ensembl_main/ensembl_compara/scripts/view_alignment:$PATH

in csh:

setenv PATH $HOME/src/ensembl_main/ensembl_compara/scripts/view_alignment:$PATH

The Staden Package environment must be set up:

eg
export STADENROOT=/software/badger/opt/staden_production
source /software/badger/opt/staden_production/staden.profile

It will only run under X windows.

=head1 SYNPOSIS

view_alignment --help

view_alignment 
    [--mfa_file multi fasta file]
    [--reg_conf registry_configuration_file]
    [--dbname compara_database]
    [--alignment_type alignment_type]
    [--set_of_species species1:species2:species3...]
    [--species_set_name name]
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
    [--display_repeat_feature repeat1:repeat2:repeat3]
    [--file_of_repeat_feature file containing list of repeat features]
    [--pairwise_dbname pairwise_dbname]
    [--pairwise_url pairwise_url]
    [--expand_alignments]
    [--template_display]

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
~/.ensembl_init will be used. An example file (reg_public.conf) is given in this
directory

=item B<--dbname compara_db_name_or_alias>

The compara database to query. You can use either the original name or any of 
the aliases given in the registry_configuration_file. 

=item B<--compara_url url>

The location of the compara database can be defined using a url of the form:
mysql://user@host:Port/database_name

=item B<--url url>

The location of the core (species) databses can be defined using a url of the form:
mysql://user@host:Port/release_number
If the compara database is not defined by either the dbname or compara_url, the compara database in the release defined by release_number is used.

=item B<[--alignment_type]>

This should be an exisiting method_link_type eg PECAN, TRANSLATED_BLAT_NET, (B)LASTZ_NET, EPO, EPO_LOW_COVERAGE

=item B<[--set_of_species]>

The set of species used in the alignment. These should be the same as defined 
in the registry configuration file aliases. The species should be separated by 
a colon e.g. human:rat

=item B<[--species_set_name]>

The name defining the set of species eg mammals, amniotes, primates, fish, birds

=item B<[--method_link_species_set_id | mlss_id]>

Instead of defining the species_set or species_set_name and alignment_type, you can enter the 
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

=item B<--strand>

The strand, 1 for the forward strand, -1 for the reverse. Default 1.

=item B<[--genomic_align_block_id | gab_id]>

It is also possible to simply enter the genomic_align_block_id. This option 
will ignore the seq_region arguments

=item B<[--display_constrained_element_tags]>

Tags (shown as coloured blocks in the contig editor) are created showing the
position of constrained elements (conserved regions) and their 'rejected
substitution' score. Only valid if conservation scores have been calculated for
the alignment. These are shown on the "consensus line" with a tag name of "CELE".

=item B<[--display_scores]>

A tag (shown as a coloured block in the contig editor) is created for each 
base that has a conservation value and shows the conservation score. This can 
produce a lot of tags which can take a long time to be read in. Only valid if 
conservation scores have been calculated for the alignment. The tag is of type 
"CSCO"

=item B<[--display_start_end_tags]>

This options tags the first and last base in each GenomicAlign region with a tag type of "FIRST" and "LAST".

=item B<[--repeat_feature]>

Valid repeat feature name eg "MIR".
Tags (shown as coloured blocks in the contig editor) are created for each 
repeat found. Repeats have a tag type of "REPT". The repeats should be separated by a colon.

=item B<[--file_of_repeat_feature]>

A file containing a list of valid repeat feature names.
Tags (shown as coloured blocks in the contig editor) are created for each 
repeat found. Repeats have a tag type of "REPT".

=item B<[--display_exon_tags]>

Tags (shown as coloured blocks in the contig editor) are created showing the
position of coding exons. The tag is of type "EXON",

=item B<[--display_gene_tags]>

Tags (shown as coloured blocks in the contig editor) are created showing the
position of genes. The tag is of type "GENE".

=item B<[--display_utr_tags]>

Tags (shown as coloured blocks in the contig editor) are created showing the
position of utr regions. The tag is of type "UTR".

=item B<[--pairwise_mlss_id --pairwise_dbname --pairwise_url]>

Tags (shown as coloured blocks in the contig editor) are created showing the
position of the corresponding pairwise blocks defined by the database and mlss_id. 
This can be used to map pairwise blocks onto a multiple alignment. The tag is of type "GALN"

=item B<[--expand_alignments]>

Write the individual alignments for the low coverage species on separate lines.

=item B<[--template_display]>

Automatically bring up a template display. Useful for looking at an overall 
view of tags

=item B<[--gap4]>

A gap4 database name. This is of the format database_name.version_number e.g.
dbname.0 If a name is not given, a default name is 
generated of the form gap4_compara_ and then either the genomic_align_block_id 
or "$seq_region_$seq_region_start_$seq_region_end" with a version value of 0. 
If the database does not already exist, the script will create a new gap4 
database. If the gap4 database does exist, no alignments will be added to the database 
and the database will simply be opened.

=back

=head2 EXAMPLES

Using the public Ensembl database server, creating a database called a.0:
view_alignment --url mysql://anonymous@ensembldb.ensembl.org:5306/70 --alignment_type EPO_LOW_COVERAGE --species_set_name mammals --species human --seq_region 13 --seq_region_start 32911298 --seq_region_end 32913363 --gap4 a.0

Tag coding exons and constrained elements and bring up the template display:
view_alignment --url mysql://anonymous@ensembldb.ensembl.org:5306/70 --alignment_type EPO_LOW_COVERAGE --species_set_name mammals --species human --seq_region 13 --seq_region_start 32911298 --seq_region_end 32913363 --display_constrained_element_tag --display_exon_tags --template_display --gap4 a.0

Tag coding exons and utr regions
perl ~/src/ensembl_main/ensembl-compara/scripts/view_alignment/view_alignment.pl --url mysql://anonymous@ensembldb.ensembl.org:5306/70 --alignment_type EPO_LOW_COVERAGE --species_set_name mammals --species human --seq_region 22 --seq_region_start 17596942 --seq_region_end 17602420 --display_utr_tags --display_exon_tags --gap4 a.0

Using alignment genomic align block id:
view_alignment --url mysql://anonymous@ensembldb.ensembl.org:5306/70 --genomic_align_block_id 6220000028031 --gap4 a.0

Tag conservation scores (small region only)
view_alignment --url mysql://anonymous@ensembldb.ensembl.org:5306/70 --alignment_type PECAN --species_set_name amniotes --species human --seq_region 13 --seq_region_start 32911776 --seq_region_end 32911894 --display_constrained_element_tag --display_scores --gap4 a.0

Tag repeat features
perl ~/src/ensembl_main/ensembl-compara/scripts/view_alignment/view_alignment.pl --url mysql://anonymous@ensembldb.ensembl.org:5306/70 --alignment_type EPO_LOW_COVERAGE --species_set_name mammals --species human --seq_region 22 --seq_region_start 17596942 --seq_region_end 17602420 --display_repeat_feature MIR3:trf:dust  --gap4 a.0

View pairwise blocks
perl ~/src/ensembl_main/ensembl-compara/scripts/view_alignment/view_alignment.pl --url mysql://anonymous@ensembldb.ensembl.org:5306/70 --alignment_type EPO_LOW_COVERAGE --species_set_name mammals --species human --seq_region 22 --seq_region_start 17596942 --seq_region_end 17602420 --pairwise_mlss_id 577 --pairwise_url mysql://anonymous@ensembldb.ensembl.org:5306/ensembl_compara_70 --gap4 a.0

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
my $compara_url;
my $urls;
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
my $disp_utr_tags;
my $disp_gene_tags = undef;
my $template_display = 0;
my $_fofn_name = "ensembl_fofn";
my $_array_files;
my $_file_list;
my $exp_line_len = 67;
my $mfa_file;
my $pairwise_mlss_id;
my $pairwise_dbname;
my $pairwise_url;
my $expand_all_alignments = 0;
my $strand = 1;
my $species_set_name;

GetOptions(
     "help" => \$help,
     "reg_conf=s" => \$reg_conf,
     "dbname=s" => \$dbname,
     "compara_url=s" => \$compara_url,
     "url=s" => \@$urls,
     "alignment_type=s" => \$alignment_type,
     "set_of_species=s" => \$set_of_species,
     "species_set_name=s" => \$species_set_name,
     "method_link_species_set_id|mlss_id=i" => \$method_link_species_set_id,
     "genomic_align_block_id|gab_id=i" => \$align_gab_id,
     "species=s" => \$species,
     "seq_region=s" => \$seq_region,
     "seq_region_start=i" => \$seq_region_start,
     "seq_region_end=i" => \$seq_region_end,
     "strand=i" => \$strand,
     "gap4=s" => \$gap4_db,
     "display_scores" => \$disp_conservation_scores,
     "display_constrained_element_tags" => \$disp_constrained_tags,
     "display_exon_tags" => \$disp_exon_tags,
     "display_utr_tags" => \$disp_utr_tags,
     "display_gene_tags" => \$disp_gene_tags,
     "display_start_end_tags" => \$disp_start_end_tags,
     "display_repeat_feature=s" => \$set_of_repeat_features,
     "file_of_repeat_feature=s" => \$file_of_repeat_features,
     "template_display" => \$template_display,
     "mfa_file=s" => \$mfa_file,
     "pairwise_mlss_id=i" => \$pairwise_mlss_id,
     "pairwise_dbname=s" => \$pairwise_dbname,
     "pairwise_url=s" => \$pairwise_url,
     "expand_alignments" => \$expand_all_alignments,
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


#Load in alignment from multi fasta file
if (defined $mfa_file) {
    load_multi_fasta_file($mfa_file);
    exit;
}

#Load registry from configuration file
my $compara_dba;
if ($reg_conf) {
    $reg->load_all($reg_conf, 1);
    if ($dbname) {
        $compara_dba = $reg->get_DBAdaptor($dbname, "compara");
    } else {
        $compara_dba = $reg->get_DBAdaptor("Multi", "compara");
    } 
}

#Set up compara_dba from url
if ($compara_url) {
    $compara_dba = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-url=>$compara_url);
}

#Load core databases if defined via url
if ($urls) {
    foreach my $url (@$urls) {
	$reg->load_registry_from_url($url);
    }
    #Use default compara database if not defined
    $compara_dba = $reg->get_DBAdaptor("Multi", "compara") unless (defined $compara_dba);
}

#Getting Bio::EnsEMBL::Compara::GenomicAlignBlockAdaptor
my $genomic_align_block_adaptor = $compara_dba->get_GenomicAlignBlockAdaptor();

#Getting Bio::EnsEMBL::Compara::GenomicAlignTreeAdaptor
my $genomic_align_tree_adaptor = $compara_dba->get_GenomicAlignTreeAdaptor();
throw ("No genomic_align_tree adaptor") if (!$genomic_align_tree_adaptor);

# Getting Bio::EnsEMBL::Compara::MethodLinkSpeciesSetAdaptor
my $method_link_species_set_adaptor = $compara_dba->get_MethodLinkSpeciesSetAdaptor();
throw ("No method_link_species_set") if (!$method_link_species_set_adaptor);

# Getting Bio::EnsEMBL::Compara::AlignAdaptor
my $align_slice_adaptor = $compara_dba->get_AlignSliceAdaptor();
throw ("No align_slice") if (!$align_slice_adaptor);

# Getting all the Bio::EnsEMBL::Compara::GenomeDB objects
my $genome_db_adaptor = $compara_dba->get_GenomeDBAdaptor();
throw("No genome_db adaptor") if (!$genome_db_adaptor);


# Getting Bio::EnsEMBL::Compara::ConservationScore object
my $cs_adaptor;
if ($disp_conservation_scores) { 
    $cs_adaptor = $compara_dba->get_ConservationScoreAdaptor();
    throw ("No conservation scores available\n") if (!$cs_adaptor);
}

my $repeat_feature_adaptor;

#unique identifier for each sequence
my $_seq_num = 1;

#scientific name of reference species
my $species_name;

if (defined $species) {
    my $this_meta_container_adaptor = $reg->get_adaptor($species, 'core', 'MetaContainer');
    throw("Registry configuration file has no data for connecting to <$species>")
      if (!$this_meta_container_adaptor);
    #$species_name = $this_meta_container_adaptor->get_scientific_name;
    $species_name = $this_meta_container_adaptor->get_production_name;
}

#if have alignment genomic align block id
if (defined $align_gab_id) {
    my $genomic_align_block = $genomic_align_block_adaptor->fetch_by_dbID($align_gab_id);
    throw ("Invalid genomic_align_block_id") if (!$genomic_align_block);
    my $contig_num = $_seq_num;
    #if $species is set, use that as reference genomic align else used first 
    my $gas = $genomic_align_block->get_all_GenomicAligns;

    #set first ga as reference. Complement if necessary
    $genomic_align_block->reference_genomic_align($gas->[0]);
    if (defined $species_name) {
	foreach my $ga (@$gas) {
	    if ($ga->dnafrag->genome_db->name eq $species_name) {
		$genomic_align_block->reference_genomic_align($ga);
	    }
	}
    }

    if (defined($genomic_align_block->reference_genomic_align) && $genomic_align_block->reference_genomic_align->dnafrag_strand == -1) {

	#this was commented out - don't know why because looking at a block, I need
	#this
	$genomic_align_block->reverse_complement();
    }
    my $align_slice = $align_slice_adaptor->fetch_by_GenomicAlignBlock($genomic_align_block, 1, "restrict");

    #convert to tree if necessary so I get the correct alignments for 2X genomes
    if ($genomic_align_block->method_link_species_set->method->class =~ /GenomicAlignTree/) {
	$genomic_align_block = $genomic_align_tree_adaptor->fetch_by_GenomicAlignBlock($genomic_align_block);
#	print "found tree \n";
    } else {
#	print "found block\n";
    }

    #convert to tree if necessary so I get the correct alignments for 2X genomes
    writeExperimentFiles($genomic_align_block, $align_slice, $contig_num, 1);

    open (FOFN, ">$_fofn_name") || die "ERROR writing ($_fofn_name) file\n";
    print FOFN "$_file_list";
    close (FOFN);
    
    if (!defined $gap4_db) {
	$gap4_db = "gap4_compara_" . $align_gab_id . ".0";
    }

    system "view_alignment.tcl $gap4_db $_fofn_name $template_display";

    #remove experiment files
    unlink @$_array_files;
    #remove file of filenames
    unlink $_fofn_name;
    exit;
}

#Find from species and alignment type
my $method_link_species_set;
if ($method_link_species_set_id) {
    $method_link_species_set = $method_link_species_set_adaptor->fetch_by_dbID($method_link_species_set_id);
    throw("The database do not contain any data for method link species set id $method_link_species_set_id!") if (!$method_link_species_set);
} elsif ($alignment_type && $species_set_name) {
    $method_link_species_set = $method_link_species_set_adaptor->fetch_by_method_link_type_species_set_name($alignment_type, $species_set_name);
    throw("The database do not contain any $alignment_type data for species_set_name $species_set_name!") if (!$method_link_species_set);
} elsif ($alignment_type && $set_of_species) {
    my $species_list = [split(":", $set_of_species)];
    my $genome_dbs = $genome_db_adaptor->fetch_all_by_mixed_ref_lists(-SPECIES_LIST => $species_list);
    $method_link_species_set = $method_link_species_set_adaptor->fetch_by_method_link_type_GenomeDBs($alignment_type, $genome_dbs);
    throw("The database do not contain any $alignment_type data for $set_of_species!") if (!$method_link_species_set);
}

#Fetching slice for species
my $slice;
my $genomic_align_blocks;
my $slice_adaptor;

if ($seq_region) {
    $slice_adaptor = $reg->get_adaptor($species, 'core', 'Slice');
    throw("Registry configuration file has no data for connecting to <$species>") if (!$slice_adaptor);

    #Prevent trying to display an entire chromosome
    throw ("Must define seq_region_start and seq_region_end") if (!$seq_region_start || !$seq_region_end);

    $slice = $slice_adaptor->fetch_by_region('toplevel', $seq_region, $seq_region_start, $seq_region_end, $strand);
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

    #print "GAB " . $genomic_align_block->dbID . " start " . $genomic_align_block->reference_genomic_align->dnafrag_start . " end " . $genomic_align_block->reference_genomic_align->dnafrag_end . "\n";

    if ($genomic_align_block->method_link_species_set->method->class =~ /GenomicAlignTree/) {
	$genomic_align_block = $genomic_align_tree_adaptor->fetch_by_GenomicAlignBlock($genomic_align_block);
    }

    my $genomic_align = $genomic_align_block->reference_genomic_align;
    my $restricted_gab = $genomic_align_block->restrict_between_reference_positions($slice->start, $slice->end, $genomic_align);

    #don't use restricted gab here because this causes problems elsewhere
    #since the new gab doesn't retain all the information of the original gab
    #such as original strand
    my $align_slice = $align_slice_adaptor->fetch_by_Slice_MethodLinkSpeciesSet($slice, $method_link_species_set, 1, "restrict");

    #Write experiment files 
    writeExperimentFiles($restricted_gab, $align_slice, $contig_num, 1);
}

open (FOFN, ">$_fofn_name") || die "ERROR writing ($_fofn_name) file\n";
print FOFN "$_file_list";
close (FOFN);

#Automatically create gap4 database name
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
    my $done_once = 0;

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

    #writeSequences($align_slice, $contig_num, $new_contig);

    #need to condense down the alignments from the target species into one alignment
    my $segments;
    my $tree_ga;
    if ($gab->isa('Bio::EnsEMBL::Compara::GenomicAlignTree')) {
        #use GenomicAlignTree 
        #to expand all alignments
        if ($expand_all_alignments) {
            foreach my $this_node (@{$gab->get_all_sorted_genomic_align_nodes()}) {
                my $genomic_align_group = $this_node->genomic_align_group;
                next if (!$genomic_align_group);
                my $new_genomic_aligns = [];
                
                foreach my $this_genomic_align (@{$genomic_align_group->get_all_GenomicAligns}) {
                    push @$segments, $this_genomic_align;
                }
            }
        } else {
            #to compact all the alignments
            #order according to tree. Need to define ref species
            foreach my $this_genomic_align_tree (@{$gab->get_all_sorted_genomic_align_nodes()}) {
                next if (!$this_genomic_align_tree->genomic_align_group);
                push(@{$segments}, $this_genomic_align_tree->genomic_align_group);
            }
        }
    } else {
        $segments = $gab->get_all_GenomicAligns;
    }

    #create mfa file of multiple alignment from genomic align block
    foreach my $this_segment (@{$segments}) {

	my $filename = "ensembl_$_seq_num" . ".exp";
	my $aligned_sequence = $this_segment->aligned_sequence;
	next if (!defined $aligned_sequence);

	$aligned_sequence =~ tr/-/*/;
	$aligned_sequence =~ s/(.{60})/$1\n/g;
	$aligned_sequence =~ s/(.*)/     $1/g;

        open my $exp_fh, ">$filename" or die "ERROR writing ($filename) file\n";

	my $name;
	if (UNIVERSAL::isa($this_segment, "Bio::EnsEMBL::Compara::GenomicAlignTree")) {
	    $name = $this_segment->genomic_align_group->genome_db->name;
	} else {
	    $name = $this_segment->genome_db->name;
	}

	$name =~ tr/ /_/;
	#print "name $name\n";
	#print "name " . $name . " " . $aligned_sequence . "\n";
	if ($new_contig) {
	    $contig_num = $name . "_" . $_seq_num;
	}
	print $exp_fh "ID   " . $name . "_$_seq_num\n";
	if ($new_contig) {
	    print $exp_fh "AP   *new* + 0 0\n";
	} else {
	    print $exp_fh "AP   $contig_num + 0 0\n";
	}

	my $genomic_aligns; 
	if (UNIVERSAL::isa($this_segment, "Bio::EnsEMBL::Compara::GenomicAlignTree")) {
	    $genomic_aligns = $this_segment->genomic_align_group->get_all_GenomicAligns;
        } elsif (UNIVERSAL::isa($this_segment, "Bio::EnsEMBL::Compara::GenomicAlignGroup")) {
            #When have GenomicAlignTree when $expand_all_alignments is false
            $genomic_aligns = $this_segment->get_all_GenomicAligns;
	} else {
	    $genomic_aligns->[0] = $this_segment;
	}
	foreach my $genomic_align (@$genomic_aligns) {
            #print "GENOMIC ALIGN " . $genomic_align->dnafrag->genome_db->name . "\n";

	    #write gene tags
	    if (defined $disp_gene_tags) {
		my $slice = $genomic_align->get_Slice;
		next if (!defined $slice);
                my $gene_array = getGenes($slice);
                writeFeats("gene", $gene_array, $genomic_align, $exp_fh);
	    }
	    
	    #write exon tags
	    if (defined $disp_exon_tags) {
		#my $min_length = 57;
		my $min_length = 1;

		my $slice = $genomic_align->get_Slice;
		next unless (defined $slice);
		my $exon_array = getCodingExons($slice, $min_length);
                writeFeats("exon", $exon_array, $genomic_align, $exp_fh);
            }

            #write utr tags
            if ($disp_utr_tags) {
                my $slice = $genomic_align->get_Slice;
		next unless(defined $slice);
		my $utr_array = getUtrs($slice);
                writeFeats("utr", $utr_array, $genomic_align, $exp_fh);
            }

	    #write constrained element tags
	    #only do once (written on consensus)
	    if (!$done_once && $disp_constrained_tags) {
		    writeConstrainedBlocks($align_slice, $exp_fh);
	    }

	    #write conservation score tags
	    #only do once (written on consensus)
	    if (!$done_once && $disp_conservation_scores) {
		writeConservationScores($align_slice, $exp_fh);	    
	    }
	    
	    #write repeat feature tags
	    if (defined $set_of_repeat_features || defined $file_of_repeat_features) {
		foreach my $a_slice (@{$align_slice->get_all_Slices}) {
		    my $original_feature = $a_slice->get_all_underlying_Slices($a_slice->start, $a_slice->end)->[0];
		    
		    #need to find the current genomic_align in the align_slice list.
		    if ($a_slice->genome_db->name eq $genomic_align->genome_db->name && $original_feature->seq_region_name eq $genomic_align->dnafrag->name && $original_feature->start == $genomic_align->dnafrag_start && $original_feature->end == $genomic_align->dnafrag_end) {
			
			writeRepeatFeatures($a_slice, $gab->length, $repeat_feature_list, $exp_fh);
		    }
		}
	    }

	    #write start/end tags
	    if ($disp_start_end_tags) {
		writeStartEndTags($genomic_align,$exp_fh); 
	    }

	    #write pairwise blocks on reference sequence
	    if (defined $pairwise_mlss_id) {
                my $p_mlss_adaptor;
                my $pairwise_compara_dba;
                
                if ($pairwise_dbname) {
                    $pairwise_compara_dba = $reg->get_adaptor($pairwise_dbname, 'compara');
                } elsif ($pairwise_url) {
                    $pairwise_compara_dba = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-url=>$pairwise_url);
                }

		if ($genomic_align == $gab->reference_genomic_align) {
                    writePairwiseBlocks($pairwise_compara_dba, $genomic_align, $pairwise_mlss_id, $exp_fh);
                } else {
                    my $pairwise_name;
                    my $p_mlss_adaptor = $pairwise_compara_dba->get_MethodLinkSpeciesSetAdaptor();
                    throw ("No method_link_species_set") if (!$p_mlss_adaptor);

                    my $pairwise_mlss = $p_mlss_adaptor->fetch_by_dbID($pairwise_mlss_id);
                    throw("The database do not contain any data for method link species set id $method_link_species_set_id!") if (!$pairwise_mlss);

                    #find the non-reference pairwise name
                    foreach my $spp (@{$pairwise_mlss->species_set->genome_dbs}) {
                        if ($spp->name ne $species_name) {
                            $pairwise_name = $spp->name;
                            last;
                        }
                    }
                    if ($pairwise_name eq $genomic_align->genome_db->name) {
                        writePairwiseBlocks($pairwise_compara_dba, $genomic_align, $pairwise_mlss_id, $exp_fh);
                    }
                }
            }
        }

	#write out sequence
	print $exp_fh "SQ\n";
	print $exp_fh "$aligned_sequence\n";
	print $exp_fh "//";
	close($exp_fh);
	$_file_list .= "$filename\n";
	push @$_array_files, $filename;
	$_seq_num++;
	$new_contig = 0;
        $done_once = 1;
    }
}

#convert from chromosome coords to alignment coords
#returns $chr_pos in alignment coords
sub findAlignPos {
    my ($chr_pos, $total_chr_pos, $cigar_line) = @_;

    #Cigar_line must contain at least one M 
    if ($cigar_line !~ /M/) {
        return $chr_pos;
    }

    my @cig = ( $cigar_line =~ /(\d*[GMDXI])/g );

    my $i = 0;

    my ($cigType, $cigLength);
    my $total_pos = 0;
    my $align_pos;
    my $last_total_pos; #Deal with the end of low coverage genomic_aligns which may end in D and X

    #convert chr_pos into alignment coords
    while ($total_chr_pos <= $chr_pos && $i < @cig) {
	#print "i $i $cig[$i]\n";
	my $cigElem = $cig[$i++];
	if (! defined $cigElem) {
	    #print "total_chr_pos $total_chr_pos chr_pos $chr_pos i $i\n";
	    next;
	}

	$cigType = substr( $cigElem, -1, 1 );
	$cigLength = substr( $cigElem, 0 ,-1 );
	$cigLength = 1 unless ($cigLength =~ /^\d+$/);

	if ($cigType ne "I") {
	    $total_pos += $cigLength;
	}
	if( $cigType eq "M" || $cigType eq "I") {
	    $total_chr_pos += $cigLength;

            $last_total_pos = $total_pos;
	}
    }
    my $start_offset = $total_chr_pos - $chr_pos;

    if ($cigType eq "M") {
	$align_pos = $total_pos - $start_offset + 1;
    } else {
        $align_pos = $last_total_pos; #Catch the case when finished the cigar_line which does not end with M
    }
    return $align_pos;
}

#get genes
sub getGenes {
    my ($slice) = @_;

    my @genes;
    foreach my $gene (@{$slice->get_all_Genes}) {
        $gene->seqname("GENE");
        push @genes, $gene;
    }
    my $gene_array = [sort {$a->start <=> $b->start} @genes];
    return $gene_array;
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
                            $exon->seqname("EXON"); #tag name for contig editor
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

#get utrs
sub getUtrs {
    my ($slice) = @_;

    my $all_features;

    my $genes = $slice->get_all_Genes_by_type('protein_coding');
    foreach my $this_gene (@$genes) {
        my $transcripts = $this_gene->get_all_Transcripts;
        foreach my $this_transcript (@$transcripts) {
            next if ($this_transcript->biotype ne "protein_coding");
            foreach my $exon (@{$this_transcript->get_all_Exons}) {
                my ($start, $end);
                #5' utr
                next if (!$this_transcript->coding_region_start);
                if ($exon->start < $this_transcript->coding_region_start) {
                    $start = $exon->start;
                    if ($exon->end < $this_transcript->coding_region_start) {
                        $end = $exon->end;
                    } else {
                        $end = $this_transcript->coding_region_start-1;
                    }
                    my $utr = new Bio::EnsEMBL::Exon(-start => $start,
                                                     -end => $end,
                                                     -slice => $slice,
                                                     -strand => $this_transcript->strand,
                                                     -stable_id => $exon->stable_id,
                                                     -seqname => "UTRS"); #tag name for contig editor
                    if ($utr->end - $utr->start >= 0) {
                        push @$all_features, $utr;
                    }
                }
                #3' utr
                next if (!$this_transcript->coding_region_end);
                if ($exon->end > $this_transcript->coding_region_end) {
                    $end = $exon->end;
                    if ($exon->start > $this_transcript->coding_region_end) {
                        $start = $exon->start;
                    } else {
                        $start = $this_transcript->coding_region_end+1;
                    }
                    my $utr = new Bio::EnsEMBL::Exon(-start => $start,
                                                     -end => $end,
                                                     -slice => $slice,
                                                     -strand => $this_transcript->strand,
                                                     -stable_id => $exon->stable_id,
                                                     -seqname => "UTRS"); #tag name for contig editor
                    if ($utr->end - $utr->start >= 0) {
                        push @$all_features, $utr;
                    }
                }
            }
        }
    }
    my $utr_array;
    if ($all_features) {
        $utr_array = [sort {$a->start <=> $b->start} @$all_features];
    }
    return $utr_array;

}

#Write exon/gene/utr features
sub writeFeats {
    my ($feat_name, $feat_array, $genomic_align, $exp_fh) = @_;

    foreach my $feat (@$feat_array) {
        
        my $slice = $genomic_align->get_Slice;

        #trim feat at start and end of slice
        my $f_start = $feat->start;
        my $f_end = $feat->end;
        if ($feat->start < 1) {
            $f_start = 1;
        }
        if ($feat->end > $slice->length) {
            $f_end = $slice->length;
        }
        
        #convert into alignment coords
        my $feat_start = findAlignPos($f_start, 1, $genomic_align->cigar_line);
        my $feat_end = findAlignPos($f_end, 1, $genomic_align->cigar_line);

        my $tag_name = $feat->seqname;

        printf($exp_fh "TG   %s + %d..%d %s %s %s:%d-%d:%d\n", $tag_name, $feat_start, $feat_end, $feat_name, $feat->stable_id, $genomic_align->dnafrag->name, ($feat->start + $slice->start - 1), ($feat->end + $slice->start - 1), $feat->strand);
    }
}

#add CELE tag on the consensus for each constrained element.
sub writeConstrainedBlocks {
    my ($align_slice, $exp_fh) = @_;

    my $cons_elems = $align_slice->get_all_ConstrainedElements();

    foreach my $cons_elem (@$cons_elems) {
	printf($exp_fh "TC   CELE + %d..%d Constrained element score=%d\n", 
	       $cons_elem->start, 
	       $cons_elem->end, 
	       $cons_elem->score);
    }
}

#add CSCO tag on each base on the consensus. Use with care! Can take a long
#time
sub writeConservationScores {
    my ($align_slice, $exp_fh) = @_;

    my $cons_scores = $align_slice->get_all_ConservationScores($align_slice->get_all_Slices()->[0]->length, "MAX", 1);
    my $i;
    foreach my $cons_score (@$cons_scores) {
	if ($cons_score->diff_score) {
	    $i = $cons_score->position;
	    printf($exp_fh "TC   CSCO + %d..%d score=%.3f\n", $i, $i, $cons_score->diff_score);
	}
	$i++;
    }
}

#add REPT tags on each species for repeat features 
#in repeat_feature_list
sub writeRepeatFeatures {
    my ($a_slice, $gab_length, $repeat_feature_list, $exp_fh) = @_;

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
            printf($exp_fh "TG   REPT + %d..%d %s\n", $start, $end, $name); 
	}
    }
}

#add a START and STOP tag to the first and last base of each genomic_align. Useful if 
#trying to find the first and last base of a sequence!
sub writeStartEndTags {
    my ($genomic_align, $exp_fh) = @_;

    my $start = findAlignPos($genomic_align->dnafrag_start, 
			     $genomic_align->dnafrag_start, 
			     $genomic_align->cigar_line);
    my $end = findAlignPos($genomic_align->dnafrag_end, 
			   $genomic_align->dnafrag_start, 
			   $genomic_align->cigar_line);

    printf($exp_fh "TG   FIRS + %d..%d Start %s %d\n", $start, $start, $genomic_align->dnafrag->name, $genomic_align->dnafrag_start); 
    printf($exp_fh "TG   LAST + %d..%d End %s %d\n", $end, $end, $genomic_align->dnafrag->name, $genomic_align->dnafrag_end); 
}

#add GALN tag on the consensus for each constrained element.
sub writePairwiseBlocks {
    my ($pairwise_compara_dba, $genomic_align, $pairwise_mlss_id, $exp_fh) = @_;

    my $gab_adaptor = $pairwise_compara_dba->get_GenomicAlignBlockAdaptor();
    throw ("No genomic_align_blocks") if (!$gab_adaptor);

    my $mlss_adaptor = $pairwise_compara_dba->get_MethodLinkSpeciesSetAdaptor();
    throw ("No method_link_species_set") if (!$mlss_adaptor);

    my $pairwise_mlss = $mlss_adaptor->fetch_by_dbID($pairwise_mlss_id);
    throw("The database do not contain any data for method link species set id $method_link_species_set_id!")
    if (!$pairwise_mlss);

    my $ref_slice = $genomic_align->get_Slice;
    my $gabs = 	$gab_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice($pairwise_mlss, $genomic_align->get_Slice,undef,undef,1);

    foreach my $gab (@$gabs) {
	my $ga = $gab->reference_genomic_align;
	my $non_ref = $gab->get_all_non_reference_genomic_aligns->[0];

	my @pairwise_ref_slices;

	if ($genomic_align->dnafrag->coord_system_name ne $ga->dnafrag->coord_system_name) {
	    my $projections = $ga->get_Slice->project($genomic_align->dnafrag->coord_system_name);
	    foreach my $proj (@$projections) {	
		my $new_slice = $proj->to_Slice();
		#print "new slice " . $new_slice->start . " " . $new_slice->end . $new_slice->name . "\n";
		push @pairwise_ref_slices, $proj->to_Slice();
	    }
 	} else {
	    $pairwise_ref_slices[0] = $ga->get_Slice;
	}
	foreach my $pairwise_ref_slice (@pairwise_ref_slices) {

	    my $start = findAlignPos($pairwise_ref_slice->start, 
				     $genomic_align->dnafrag_start, 
				     $genomic_align->cigar_line);
	    my $end = findAlignPos($pairwise_ref_slice->end, 
				   $genomic_align->dnafrag_start, 
				   $genomic_align->cigar_line);
	    
	    printf($exp_fh "TG   GALN + %d..%d %s start=%d end=%d non-ref %s start=%d end=%d\n", $start, $end, $ga->dnafrag->name, $ga->dnafrag_start, $ga->dnafrag_end, $non_ref->dnafrag->name, $non_ref->dnafrag_start, $non_ref->dnafrag_end);
	}
    }
}

#Load a msa file directly, no databases needed
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
	    #only take the first word (stop at |)

	    #Normal case
	    #my ($name) = $line =~ /(\w*)/;

	    #Hack when have multiple species lines in single block
	    my $name = $line;
	    $name =~ s/\//_/;

	    #$exp_name = $line . ".exp";
	    $exp_name = $name . ".exp";
	    if (length($exp_name) >= 255) {
		$exp_name = substr $exp_name, 0, 254;
	    }
	    open (EXP, ">$exp_name") || die "ERROR writing ($exp_name) file\n";
	    #print EXP "ID   $line\n";
	    print EXP "ID   $name\n";

	    if ($new_contig) { 
		print EXP "AP   *new* + 0 0\n";
		#$contig_num = $line;
		$contig_num = $name;
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
