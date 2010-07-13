#!/usr/bin/perl
use strict;
use Bio::EnsEMBL::Registry;

use Getopt::Long;

my ($input,$debug);

GetOptions(
	   'i|input:s' => \$input,
           'd|debug:s' => \$debug,
          );

Bio::EnsEMBL::Registry->load_registry_from_db
    (-host=>"ensembldb.ensembl.org", 
     -user=>"anonymous",
    -db_version=>'58');
Bio::EnsEMBL::Registry->no_version_check(1) unless ($debug);
my $member_adaptor =
    Bio::EnsEMBL::Registry->get_adaptor
    ("Compara", "compara", "Member");
my $homology_adaptor =
    Bio::EnsEMBL::Registry->get_adaptor
    ("Compara", "compara", "Homology");

my $bioperl_dnastats = 0;
eval {require Bio::Align::DNAStatistics;};
unless ($@) { $bioperl_dnastats = 1; }

$input = 'ENSG00000139618:ENSG00000073910' unless (length($input) > 1);
my $result = undef;

foreach my $gene_id (split(':',$input)) {
  my $member = $member_adaptor->
  fetch_by_source_stable_id("ENSEMBLGENE",$gene_id);
  next unless (defined($member));
  my $all_homologies = $homology_adaptor->fetch_by_Member($member);
  next unless (defined($all_homologies));

  print "spa,labela,spb,labelb,dn,ds\n";
  foreach my $this_homology (@$all_homologies) {
    my $description = $this_homology->description;
    # next unless ($description =~ /para/);    # uncomment for paralogues only
    # next unless ($description =~ /orth/);    # uncomment for orthologs only
    # next unless ($description =~ /one2one/); # uncomment for one2one orthologs only
    my $all_member_attributes = 
    $this_homology->get_all_Member_Attribute();
    my $first_found = 0;
    my ($a,$b) = @{$this_homology->gene_list};
    my $spa = $a->taxon->short_name;
    my $spb = $b->taxon->short_name;
    my $labela = $a->stable_id . "(" . $a->display_label . ")";
    my $labelb = $b->stable_id . "(" . $b->display_label . ")";
    my $dn; my $ds;
    my $lnl = $this_homology->lnl;
    $dn = $this_homology->dn;
    $ds = $this_homology->ds;

    if (!defined($dn) || !defined($ds) || $ds eq 'na' || $dn ne 'na' ) {
      # This bit calculates dnds values using the counting method in bioperl-run
      my $aln = $this_homology->get_SimpleAlign("cdna", 1);
      if ($bioperl_dnastats) {
        my $stats = new Bio::Align::DNAStatistics;
        if($stats->can('calc_KaKs_pair')) {
          my ($seq1id,$seq2id) = map { $_->display_id } $aln->each_seq;
          my $results;
          eval { $results = $stats->calc_KaKs_pair($aln, $seq1id, $seq2id);};
          unless ($@) {
            my $counting_method_dn = $results->[0]{D_n};
            my $counting_method_ds = $results->[0]{D_s};
            $dn = $counting_method_dn;
            $ds = $counting_method_ds;
          }
        }
      }
      ##
    }
    print "$spa,$labela,$spb,$labelb,$dn,$ds\n";
  }
}
