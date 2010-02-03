#!/usr/bin/perl
use strict;
use Bio::EnsEMBL::Registry;

Bio::EnsEMBL::Registry->load_registry_from_db
    (-host=>"ensembldb.ensembl.org", 
     -user=>"anonymous");
my $human_gene_adaptor =
    Bio::EnsEMBL::Registry->get_adaptor
    ("Homo sapiens", "core", "Gene");
my $member_adaptor =
    Bio::EnsEMBL::Registry->get_adaptor
    ("Compara", "compara", "Member");
my $homology_adaptor =
    Bio::EnsEMBL::Registry->get_adaptor
    ("Compara", "compara", "Homology");

my $genes = $human_gene_adaptor->
   fetch_all_by_external_name('CTDP1');

my $result = undef;
foreach my $gene (@$genes) {
  my $member = $member_adaptor->
  fetch_by_source_stable_id("ENSEMBLGENE",$gene->stable_id);
  my $all_homologies = $homology_adaptor->fetch_by_Member($member);

  print "spa,labela,spb,labelb,dn,ds\n";
  foreach my $this_homology (@$all_homologies) {
    my $description = $this_homology->description;
    next unless ($description =~ /one2one/); # if only one2one wanted
    my $all_member_attributes = 
    $this_homology->get_all_Member_Attribute();
    my $first_found = 0;
    my ($a,$b) = @{$this_homology->gene_list};
    my $spa = $a->taxon->short_name;
    my $spb = $b->taxon->short_name;
    my $labela = $a->display_label || $a->stable_id;
    my $labelb = $b->display_label || $b->stable_id;
    my $dn; my $ds;
    my $lnl = $this_homology->lnl;
    if (0 != $lnl) {
        $dn = $this_homology->dn;
        $ds = $this_homology->ds;
        $dn = 'na' if (!defined($dn));
        $ds = 'na' if (!defined($ds));
    } else {
        # This bit calculates dnds values using the counting method in bioperl-run
        my $aln = $this_homology->get_SimpleAlign("cdna", 1);
        eval {require Bio::Align::DNAStatistics;};
        unless ($@) {
            my $stats = new Bio::Align::DNAStatistics;
            if($stats->can('calc_KaKs_pair')) {
                my ($seq1id,$seq2id) = map { $_->display_id } $aln->each_seq;
                my $results = $stats->calc_KaKs_pair($aln, $seq1id, $seq2id);
                my $counting_method_dn = $results->[0]{D_n};
                my $counting_method_ds = $results->[0]{D_s};
                $dn = $counting_method_dn;
                $ds = $counting_method_ds;
            }
        }
        ##
    }
    print "$spa,$labela,$spb,$labelb,$dn,$ds\n";
  }
}
