#!/usr/bin/env perl

use strict;
use warnings;

use Bio::EnsEMBL::Registry;
use Bio::AlignIO;


#
# This script gets all the GenomicAlignBlocks covering the orthologues
# between human and mouse (via DnaDnaAlignFeature)
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

    my $human_gene = undef;
    my $mouse_gene = undef;
    foreach my $member (@{$homology->get_all_Members}) {
        if($member->genome_db_id == $mouse_gdb_id) { $mouse_gene = $member; }
        if($member->genome_db_id == $human_gdb_id) { $human_gene = $member; }
    }
    next unless($mouse_gene and $human_gene);
    $mouse_gene->print_member;
    $human_gene->print_member;

    # get the alignments on a piece of the DnaFrag
    printf("fetch_all_by_species_region(%s,%s,%s,%s,%d,%d,%s)\n", 
            $mouse_gene->genome_db->name, $mouse_gene->genome_db->assembly,
            $human_gene->genome_db->name, $human_gene->genome_db->assembly,
            $mouse_gene->chr_name, $mouse_gene->chr_start, $mouse_gene->chr_end,
            'BLASTZ_NET');


    my $dnafeatures = $comparaDBA->get_DnaAlignFeatureAdaptor->fetch_all_by_species_region(
            $mouse_gene->genome_db->name, $mouse_gene->genome_db->assembly,
            $human_gene->genome_db->name, $human_gene->genome_db->assembly,
            $mouse_gene->chr_name, $mouse_gene->chr_start, $mouse_gene->chr_end,
            'BLASTZ_NET');

    foreach my $ddaf (@{$dnafeatures}) {
        next unless (($mouse_gene->chr_name eq $ddaf->seqname) and ($human_gene->chr_name eq $ddaf->hseqname));

        print "=====================================================\n";
        print " length: ", $ddaf->alignment_length, "; score: ", $ddaf->score, "\n";
        print "  - ", join(" : ", $ddaf->species, $ddaf->coord_system_name,
            $ddaf->seqname, $ddaf->start, $ddaf->end, $ddaf->strand), "\n";
        print "  - ", join(" : ", $ddaf->hspecies, $ddaf->coord_system_name,
            $ddaf->hseqname, $ddaf->hstart, $ddaf->hend, $ddaf->hstrand), "\n";
        print $alignIO $ddaf->get_SimpleAlign;
    }
    last if($count > 10);
}

