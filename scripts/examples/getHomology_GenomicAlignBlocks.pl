#!/usr/bin/env perl

use strict;
use warnings;

use Bio::EnsEMBL::Registry;
use Bio::AlignIO;


#
# This script gets all the BLASTZ alignments covering the orthologues
# between human and mouse (via GenomicAlignBlocks)
#

my $reg = 'Bio::EnsEMBL::Registry';

$reg->load_registry_from_db(
  -host=>'ensembldb.ensembl.org',
  -user=>'anonymous', 
);


# get compara DBAdaptor
my $comparaDBA = Bio::EnsEMBL::Registry->get_DBAdaptor('compara', 'compara');

# get GenomeDB for human and mouse
my $humanGDB = $comparaDBA->get_GenomeDBAdaptor->fetch_by_registry_name("human");
my $human_gdb_id = $humanGDB->dbID;
my $mouseGDB = $comparaDBA->get_GenomeDBAdaptor->fetch_by_registry_name("mouse");
my $mouse_gdb_id = $mouseGDB->dbID;

# get MethodLinkSpeciesSet for BLASTZ_NET alignments between human and mouse
my $blastz_mlss = $comparaDBA->get_MethodLinkSpeciesSetAdaptor->
    fetch_by_method_link_type_GenomeDBs("BLASTZ_NET", [$humanGDB, $mouseGDB]);

my $homology_mlss = $comparaDBA->get_MethodLinkSpeciesSetAdaptor->
    fetch_by_method_link_type_genome_db_ids('ENSEMBL_ORTHOLOGUES',[$human_gdb_id,$mouse_gdb_id]);

my $homology_list = $comparaDBA->get_HomologyAdaptor->fetch_all_by_MethodLinkSpeciesSet($homology_mlss);
printf("fetched %d homologies\n", scalar(@$homology_list));

# set up an AlignIO to format SimpleAlign output
my $alignIO = Bio::AlignIO->newFh(-interleaved=>1, -fh=>\*STDOUT, -format=>'psi', -idlength=>20);


my $count=0;
foreach my $homology (@{$homology_list}) {
    $count++;
    $homology->print_homology;

    my $mem_attribs = $homology->get_all_Member_Attribute;
    my $human_gene = undef;
    my $mouse_gene = undef;
    foreach my $member_attribute (@{$mem_attribs}) {
        my ($member, $atrb) = @{$member_attribute};
        if($member->genome_db_id == $mouse_gdb_id) { $mouse_gene = $member; }
        if($member->genome_db_id == $human_gdb_id) { $human_gene = $member; }
    }
    next unless($mouse_gene and $human_gene);
    $mouse_gene->print_member;
    $human_gene->print_member;

    my $dnafrag = $comparaDBA->get_DnaFragAdaptor->fetch_by_GenomeDB_and_name($mouseGDB, $mouse_gene->chr_name);
    unless($dnafrag) { print("oops no dnafrag\n"); next; }

# get the alignments on a piece of the DnaFrag
    my $genomic_align_blocks = $comparaDBA->get_GenomicAlignBlockAdaptor->fetch_all_by_MethodLinkSpeciesSet_DnaFrag( $blastz_mlss, $dnafrag, $mouse_gene->chr_start, $mouse_gene->chr_end);

    foreach my $gab (@{$genomic_align_blocks}) {
        my $all_genomic_aligns = $gab->get_all_GenomicAligns();
        my $valid = 1;
        foreach my $ga (@$all_genomic_aligns) {
            $valid = 0 if (($ga->dnafrag->genome_db->dbID == $human_gdb_id) and ($ga->dnafrag->name ne $human_gene->chr_name));
            $valid = 0 if (($ga->dnafrag->genome_db->dbID == $mouse_gdb_id) and ($ga->dnafrag->name ne $mouse_gene->chr_name));
        }
        next unless ($valid);

        print "Bio::EnsEMBL::Compara::GenomicAlignBlock #", $gab->dbID, "\n";
        print "=====================================================\n";
        print " length: ", $gab->length, "; score: ", $gab->score, "\n";
        foreach my $ga (@$all_genomic_aligns) {
            print "  - ", join(" : ", $ga->dnafrag->genome_db->name, $ga->dnafrag->coord_system_name,
                $ga->dnafrag->name, $ga->dnafrag_start, $ga->dnafrag_end, $ga->dnafrag_strand), "\n";
        }
        print $alignIO $gab->get_SimpleAlign;
    }
    last if($count > 10);
}

