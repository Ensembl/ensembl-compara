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

This script includes 64 tests.

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
    plan tests => 64
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
# my $mus_musculus = Bio::EnsEMBL::Test::MultiTestDB->new("mus_musculus");
my $rattus_norvegicus = Bio::EnsEMBL::Test::MultiTestDB->new("rattus_norvegicus");
Bio::EnsEMBL::Test::MultiTestDB->new("gallus_gallus");

my $compara_db = $multi->get_DBAdaptor( "compara" );
  
my $genomic_align;
my $genomic_align_block;
my $all_genomic_aligns;
my $genomic_align_adaptor = $compara_db->get_GenomicAlignAdaptor();
my $dnafrag_adaptor = $compara_db->get_DnaFragAdaptor();
my $genomeDB_adaptor = $compara_db->get_GenomeDBAdaptor();

debug("Test Bio::EnsEMBL::Compara::DBSQL::GenomicAlignAdaptor fetch_by_dbID(11714534) method");
  $genomic_align = $genomic_align_adaptor->fetch_by_dbID(11714534);
  ok($genomic_align);
  ok($genomic_align->adaptor, $genomic_align_adaptor);
  ok($genomic_align->dbID, 11714534);
  ok($genomic_align->genomic_align_block_id, 5857270);
  ok($genomic_align->method_link_species_set_id, 72);
  ok($genomic_align->dnafrag_id, 19);
  ok($genomic_align->dnafrag_start, 49999812);
  ok($genomic_align->dnafrag_end, 50000028);
  ok($genomic_align->dnafrag_strand, 1);
  ok($genomic_align->cigar_line, "86M2G63MG34M7G6M12G15M44G13M");
  ok($genomic_align->level_id, 1);


debug("Test Bio::EnsEMBL::Compara::DBSQL::GenomicAlignAdaptor fetch_by_dbID(22609531) method");
  $genomic_align = $genomic_align_adaptor->fetch_by_dbID(22609531);
  ok($genomic_align);
  ok($genomic_align->adaptor, $genomic_align_adaptor);
  ok($genomic_align->dbID, 22609531);
  ok($genomic_align->genomic_align_block_id, 11304765);
  ok($genomic_align->method_link_species_set_id, 72);
  ok($genomic_align->dnafrag_id, 58);
  ok($genomic_align->dnafrag_start, 18153645);
  ok($genomic_align->dnafrag_end, 18153690);
  ok($genomic_align->dnafrag_strand, -1);
  ok($genomic_align->cigar_line, "46M");
  ok($genomic_align->level_id, 2);


debug("Test Bio::EnsEMBL::Compara::DBSQL::GenomicAlignAdaptor fetch_all_by_genomic_align_block(4018490) method");
  $all_genomic_aligns = $genomic_align_adaptor->fetch_all_by_genomic_align_block(4018490);
  ok(scalar(@$all_genomic_aligns), 2, "fetch_all_by_genomic_align_block(3639645) sould return 2 objects");
  check_all_genomic_aligns($all_genomic_aligns);

debug("Test Bio::EnsEMBL::Compara::DBSQL::GenomicAlignAdaptor::fetch_all_by_genomic_align_block(\$genomic_aling_block) method");
  $genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock(
          -dbID=>4018490,
          -adaptor=>$compara_db->get_GenomicAlignBlockAdaptor
      );
  $all_genomic_aligns = $genomic_align_adaptor->fetch_all_by_genomic_align_block($genomic_align_block);
  ok(scalar(@$all_genomic_aligns), 2, "fetch_all_by_genomic_align_block(\$genomic_aling_block) sould return 2 objects");
  check_all_genomic_aligns($all_genomic_aligns);


exit 0;

sub check_all_genomic_aligns {
  my ($all_genomic_aligns) = @_;

  foreach my $this_genomic_align (@{$all_genomic_aligns}) {
    if ($this_genomic_align->dbID == 8036973) {
      ok($this_genomic_align->dbID, 8036973);
      ok($this_genomic_align->adaptor, $genomic_align_adaptor, "unexpected genomic_align_adapto");
      ok($this_genomic_align->genomic_align_block_id, 4018490);
      ok($this_genomic_align->method_link_species_set_id, 72);
      ok($this_genomic_align->dnafrag_id, 19);
      ok($this_genomic_align->dnafrag_start, 50044148);
      ok($this_genomic_align->dnafrag_end, 50044227);
      ok($this_genomic_align->dnafrag_strand, 1);
      ok($this_genomic_align->level_id, 2);
      ok($this_genomic_align->cigar_line, "80M");
    } elsif ($this_genomic_align->dbID == 8036987) {
      ok($this_genomic_align->dbID, 8036987);
      ok($this_genomic_align->adaptor, $genomic_align_adaptor, "unexpected genomic_align_adapto");
      ok($this_genomic_align->genomic_align_block_id, 4018490);
      ok($this_genomic_align->method_link_species_set_id, 72);
      ok($this_genomic_align->dnafrag_id, 53);
      ok($this_genomic_align->dnafrag_start, 82065037);
      ok($this_genomic_align->dnafrag_end, 82065116);
      ok($this_genomic_align->dnafrag_strand, 1);
      ok($this_genomic_align->level_id, 2);
      ok($this_genomic_align->cigar_line, "80M");
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
