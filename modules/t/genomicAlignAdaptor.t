#!/usr/local/ensembl/bin/perl -w

#
# Test script for Bio::EnsEMBL::Compara::DBSQL::GenomicAlignAdaptor module
#
# Written by Javier Herrero (jherrero@ebi.ac.uk)
#
# Copyright (c) 2004. EnsEMBL Team
#
# You may distribute this module under the same terms as perl itself

=head1 NAME

genomicAlignAdaptor.t

=head1 INSTALLATION

*_*_*_*_*_*_*_*_*_*_*_*_*_*_   W A R N I N G  _*_*_*_*_*_*_*_*_*_*_*_*_*_*

YOU MUST EDIT THE <MultiTestDB.conf> FILE BEFORE USING THIS TEST SCRIPT!!!

*_*_*_*_*_*_*_*_*_*_*_*_*_*_   W A R N I N G  _*_*_*_*_*_*_*_*_*_*_*_*_*_*

Please, read the README file for instructions.

=head1 SYNOPSIS

For running this test only:
perl -w ../../../ensembl-test/scripts/runtests.pl genomicAlignAdaptor.t

For running all the test scripts:
perl -w ../../../ensembl-test/scripts/runtests.pl

For running all the test scripts and cleaning the database afterwards:
perl -w ../../../ensembl-test/scripts/runtests.pl -c

=head1 DESCRIPTION

This script uses a small compara database build following the specifitions given in the MultiTestDB.conf file.

This script (as far as possible) tests all the methods defined in the
Bio::EnsEMBL::Compara::DBSQL::GenomicAlignAdaptor module.

This script includes 106 tests.

=head1 AUTHOR

Javier Herrero (jherrero@ebi.ac.uk)

=head1 COPYRIGHT

Copyright (c) 2004. EnsEMBL Team

You may distribute this module under the same terms as perl itself

=head1 CONTACT

This modules is part of the EnsEMBL project (http://www.ensembl.org)

Questions can be posted to the ensembl-dev mailing list:
ensembl-dev@ebi.ac.uk

=cut


# Think about adding "Rat -- Mouse deduced" and "Mouse -- Rat deduced"

use strict;

BEGIN { $| = 1;  
    use Test;
    plan tests => 64;
}

use Bio::EnsEMBL::Utils::Exception qw (warning verbose);
use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::Test::TestUtils;
use Bio::EnsEMBL::Compara::GenomicAlignBlock;
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;

# switch off the debug prints 
our $verbose = 0;

my $multi = Bio::EnsEMBL::Test::MultiTestDB->new( "multi" );
my $homo_sapiens = Bio::EnsEMBL::Test::MultiTestDB->new("homo_sapiens");
my $mus_musculus = Bio::EnsEMBL::Test::MultiTestDB->new("mus_musculus");
my $rattus_norvegicus = Bio::EnsEMBL::Test::MultiTestDB->new("rattus_norvegicus");
Bio::EnsEMBL::Test::MultiTestDB->new("gallus_gallus");
Bio::EnsEMBL::Test::MultiTestDB->new("bos_taurus");
Bio::EnsEMBL::Test::MultiTestDB->new("canis_familiaris");
Bio::EnsEMBL::Test::MultiTestDB->new("macaca_mulatta");
Bio::EnsEMBL::Test::MultiTestDB->new("monodelphis_domestica");
Bio::EnsEMBL::Test::MultiTestDB->new("ornithorhynchus_anatinus");
Bio::EnsEMBL::Test::MultiTestDB->new("pan_troglodytes");


my $compara_db = $multi->get_DBAdaptor( "compara" );
  
my $genomic_align;
my $genomic_align_block;
my $all_genomic_aligns;
my $genomic_align_adaptor = $compara_db->get_GenomicAlignAdaptor();
my $dnafrag_adaptor = $compara_db->get_DnaFragAdaptor();
my $genomeDB_adaptor = $compara_db->get_GenomeDBAdaptor();

my $sth;
my ($ga_id, $gab_id, $mlss_id, $df_id, $dfs, $dfe, $cg);

$sth = $compara_db->dbc->prepare("SELECT
      genomic_align_id, genomic_align_block_id, method_link_species_set_id, dnafrag_id,
      dnafrag_start, dnafrag_end, cigar_line
    FROM genomic_align WHERE level_id = 1 and dnafrag_strand = 1 LIMIT 1");
$sth->execute();
($ga_id, $gab_id, $mlss_id, $df_id, $dfs, $dfe, $cg) = $sth->fetchrow_array();
$sth->finish();

debug("Test Bio::EnsEMBL::Compara::DBSQL::GenomicAlignAdaptor fetch_by_dbID($ga_id) method");
  $genomic_align = $genomic_align_adaptor->fetch_by_dbID($ga_id);
  ok($genomic_align);
  ok($genomic_align->adaptor, $genomic_align_adaptor);
  ok($genomic_align->dbID, $ga_id);
  ok($genomic_align->genomic_align_block_id, $gab_id);
  ok($genomic_align->method_link_species_set_id, $mlss_id);
  ok($genomic_align->dnafrag_id, $df_id);
  ok($genomic_align->dnafrag_start, $dfs);
  ok($genomic_align->dnafrag_end, $dfe);
  ok($genomic_align->dnafrag_strand, 1);
  ok($genomic_align->cigar_line, $cg);
  ok($genomic_align->level_id, 1);


$sth = $compara_db->dbc->prepare("SELECT
      genomic_align_id, genomic_align_block_id, method_link_species_set_id, dnafrag_id,
      dnafrag_start, dnafrag_end, cigar_line
    FROM genomic_align WHERE level_id = 2 and dnafrag_strand = -1 LIMIT 1");
$sth->execute();
($ga_id, $gab_id, $mlss_id, $df_id, $dfs, $dfe, $cg) = $sth->fetchrow_array();
$sth->finish();

debug("Test Bio::EnsEMBL::Compara::DBSQL::GenomicAlignAdaptor fetch_by_dbID($ga_id) method");
  $genomic_align = $genomic_align_adaptor->fetch_by_dbID($ga_id);
  ok($genomic_align);
  ok($genomic_align->adaptor, $genomic_align_adaptor);
  ok($genomic_align->dbID, $ga_id);
  ok($genomic_align->genomic_align_block_id, $gab_id);
  ok($genomic_align->method_link_species_set_id, $mlss_id);
  ok($genomic_align->dnafrag_id, $df_id);
  ok($genomic_align->dnafrag_start, $dfs);
  ok($genomic_align->dnafrag_end, $dfe);
  ok($genomic_align->dnafrag_strand, -1);
  ok($genomic_align->cigar_line, $cg);
  ok($genomic_align->level_id, 2);


$sth = $compara_db->dbc->prepare("
    SELECT
      ga1.genomic_align_id, ga1.genomic_align_block_id, ga1.method_link_species_set_id,
      ga1.dnafrag_id, ga1.dnafrag_start, ga1.dnafrag_end, ga1.dnafrag_strand,
      ga1.cigar_line, ga1.level_id,
      ga2.genomic_align_id, ga2.genomic_align_block_id, ga2.method_link_species_set_id,
      ga2.dnafrag_id, ga2.dnafrag_start, ga2.dnafrag_end, ga2.dnafrag_strand,
      ga2.cigar_line, ga2.level_id
    FROM genomic_align ga1, genomic_align ga2
    WHERE ga1.genomic_align_block_id = ga2.genomic_align_block_id and ga1.genomic_align_id != ga2.genomic_align_id LIMIT 1");
$sth->execute();
my ($ga_id1, $gab_id1, $mlss_id1, $df_id1, $dfs1, $dfe1, $dfst1, $cg1, $lvl1,
 $ga_id2, $gab_id2, $mlss_id2, $df_id2, $dfs2, $dfe2, $dfst2, $cg2, $lvl2) =
    $sth->fetchrow_array();
$sth->finish();

debug("Test Bio::EnsEMBL::Compara::DBSQL::GenomicAlignAdaptor fetch_all_by_genomic_align_block_id($gab_id1) method");
  $all_genomic_aligns = $genomic_align_adaptor->fetch_all_by_genomic_align_block_id($gab_id1);
  ok(scalar(@$all_genomic_aligns), 2, "fetch_all_by_genomic_align_block($gab_id1) should return 2 objects");
  check_all_genomic_aligns($all_genomic_aligns);

debug("Test Bio::EnsEMBL::Compara::DBSQL::GenomicAlignAdaptor::fetch_all_by_GenomicAlignBlock(\$genomic_aling_block) method");
  $genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock(
          -dbID=>$gab_id1,
          -adaptor=>$compara_db->get_GenomicAlignBlockAdaptor
      );
  $all_genomic_aligns = $genomic_align_adaptor->fetch_all_by_GenomicAlignBlock($genomic_align_block);
  ok(scalar(@$all_genomic_aligns), 2, "fetch_all_by_genomic_align_block(\$genomic_aling_block) should return 2 objects");
  check_all_genomic_aligns($all_genomic_aligns);

exit (0);


sub check_all_genomic_aligns {
  my ($all_genomic_aligns) = @_;

  foreach my $this_genomic_align (@{$all_genomic_aligns}) {
    if ($this_genomic_align->dbID == $ga_id1) {
      ok($this_genomic_align->dbID, $ga_id1);
      ok($this_genomic_align->adaptor, $genomic_align_adaptor, "unexpected genomic_align_adaptor");
      ok($this_genomic_align->genomic_align_block_id, $gab_id1);
      ok($this_genomic_align->method_link_species_set_id, $mlss_id1);
      ok($this_genomic_align->dnafrag_id, $df_id1);
      ok($this_genomic_align->dnafrag_start, $dfs1);
      ok($this_genomic_align->dnafrag_end, $dfe1);
      ok($this_genomic_align->dnafrag_strand, $dfst1);
      ok($this_genomic_align->cigar_line, $cg1);
      ok($this_genomic_align->level_id, $lvl1);
    } elsif ($this_genomic_align->dbID == $ga_id2) {
      ok($this_genomic_align->dbID, $ga_id2);
      ok($this_genomic_align->adaptor, $genomic_align_adaptor, "unexpected genomic_align_adaptor");
      ok($this_genomic_align->genomic_align_block_id, $gab_id2);
      ok($this_genomic_align->method_link_species_set_id, $mlss_id2);
      ok($this_genomic_align->dnafrag_id, $df_id2);
      ok($this_genomic_align->dnafrag_start, $dfs2);
      ok($this_genomic_align->dnafrag_end, $dfe2);
      ok($this_genomic_align->dnafrag_strand, $dfst2);
      ok($this_genomic_align->cigar_line, $cg2);
      ok($this_genomic_align->level_id, $lvl2);
    } else {
      ok(0, 1, "unexpected genomic_align->dbID (".$this_genomic_align->dbID.")");
      ok($this_genomic_align->adaptor, $genomic_align_adaptor, "unexpected genomic_align_adaptor");
      ok($this_genomic_align->genomic_align_block_id, -1);
      ok($this_genomic_align->method_link_species_set_id, -1);
      ok($this_genomic_align->dnafrag_id, -1);
      ok($this_genomic_align->dnafrag_start, -1);
      ok($this_genomic_align->dnafrag_end, -1);
      ok($this_genomic_align->dnafrag_strand, 0);
      ok($this_genomic_align->level_id, -1);
      ok($this_genomic_align->cigar_line, "UNKNOWN!!!");
    }
  }
}
