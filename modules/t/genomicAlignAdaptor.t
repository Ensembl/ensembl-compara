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
my $mus_musculus = Bio::EnsEMBL::Test::MultiTestDB->new("mus_musculus");
my $rattus_norvegicus = Bio::EnsEMBL::Test::MultiTestDB->new("rattus_norvegicus");

my $compara_db = $multi->get_DBAdaptor( "compara" );
  
my $genomic_align;
my $genomic_align_block;
my $all_genomic_aligns;
my $genomic_align_adaptor = $compara_db->get_GenomicAlignAdaptor();
my $dnafrag_adaptor = $compara_db->get_DnaFragAdaptor();
my $genomeDB_adaptor = $compara_db->get_GenomeDBAdaptor();

# 
# 1-11
# 
debug("Test Bio::EnsEMBL::Compara::DBSQL::GenomicAlignAdaptor fetch_by_dbID(7279606) method");
  $genomic_align = $genomic_align_adaptor->fetch_by_dbID(7279606);
  ok($genomic_align);
  ok($genomic_align->adaptor, $genomic_align_adaptor);
  ok($genomic_align->dbID, 7279606);
  ok($genomic_align->genomic_align_block_id, 3639804);
  ok($genomic_align->method_link_species_set_id, 2);
  ok($genomic_align->dnafrag_id, 19);
  ok($genomic_align->dnafrag_start, 50007134);
  ok($genomic_align->dnafrag_end, 50007289);
  ok($genomic_align->dnafrag_strand, 1);
  ok($genomic_align->cigar_line, "15MG78MG63M");
  ok($genomic_align->level_id, 1);

# 
# 12-22
# 
debug("Test Bio::EnsEMBL::Compara::DBSQL::GenomicAlignAdaptor fetch_by_dbID(9505794):");
  $genomic_align = $genomic_align_adaptor->fetch_by_dbID(9505794);
  ok($genomic_align);
  ok($genomic_align->adaptor, $genomic_align_adaptor);
  ok($genomic_align->dbID, 9505794);
  ok($genomic_align->genomic_align_block_id, 4752897);
  ok($genomic_align->method_link_species_set_id, 1);
  ok($genomic_align->dnafrag_id, 60);
  ok($genomic_align->dnafrag_start, 107004462);
  ok($genomic_align->dnafrag_end, 107004485);
  ok($genomic_align->dnafrag_strand, -1);
  ok($genomic_align->cigar_line, "24M");
  ok($genomic_align->level_id, 3);

# 
# 23-43
# 
debug("Test Bio::EnsEMBL::Compara::DBSQL::GenomicAlignAdaptor fetch_all_by_genomic_align_block(3639645) method");
  $all_genomic_aligns = $genomic_align_adaptor->fetch_all_by_genomic_align_block(3639645);
  ok(scalar(@$all_genomic_aligns), 2, "fetch_all_by_genomic_align_block(3639645) sould return 2 objects");
  foreach my $this_genomic_align (@{$all_genomic_aligns}) {
    if ($this_genomic_align->dbID == 7279289) {
      ok($this_genomic_align->dbID, 7279289);
      ok($this_genomic_align->adaptor, $genomic_align_adaptor, "unexpected genomic_align_adapto");
      ok($this_genomic_align->genomic_align_block_id, 3639645);
      ok($this_genomic_align->method_link_species_set_id, 2);
      ok($this_genomic_align->dnafrag_id, 19);
      ok($this_genomic_align->dnafrag_start, 49999738);
      ok($this_genomic_align->dnafrag_end, 50000033);
      ok($this_genomic_align->dnafrag_strand, 1);
      ok($this_genomic_align->level_id, 1);
      ok($this_genomic_align->cigar_line, "19M29G31M12G11M44G10M26G27M37G62M2G97M2G10M21G11M6G18M");
    } elsif ($this_genomic_align->dbID == 7279290) {
      ok($this_genomic_align->dbID, 7279290);
      ok($this_genomic_align->adaptor, $genomic_align_adaptor, "unexpected genomic_align_adapto");
      ok($this_genomic_align->genomic_align_block_id, 3639645);
      ok($this_genomic_align->method_link_species_set_id, 2);
      ok($this_genomic_align->dnafrag_id, 34);
      ok($this_genomic_align->dnafrag_start, 66608068);
      ok($this_genomic_align->dnafrag_end, 66608528);
      ok($this_genomic_align->dnafrag_strand, 1);
      ok($this_genomic_align->level_id, 1);
      ok($this_genomic_align->cigar_line, "265MG94M13G102M");
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

# 
# 44-64
# 
debug("Test Bio::EnsEMBL::Compara::DBSQL::GenomicAlignAdaptor::fetch_all_by_genomic_align_block(\$genomic_aling_block) method");
  $genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock(
          -dbID=>3639645,
          -adaptor=>$compara_db->get_GenomicAlignBlockAdaptor
      );
  $all_genomic_aligns = $genomic_align_adaptor->fetch_all_by_genomic_align_block(3639645);
  ok(scalar(@$all_genomic_aligns), 2, "fetch_all_by_genomic_align_block(3639645) sould return 2 objects");
  foreach my $this_genomic_align (@{$all_genomic_aligns}) {
    if ($this_genomic_align->dbID == 7279289) {
      ok($this_genomic_align->dbID, 7279289);
      ok($this_genomic_align->adaptor, $genomic_align_adaptor, "unexpected genomic_align_adaptor");
      ok($this_genomic_align->genomic_align_block_id, 3639645);
      ok($this_genomic_align->method_link_species_set_id, 2);
      ok($this_genomic_align->dnafrag_id, 19);
      ok($this_genomic_align->dnafrag_start, 49999738);
      ok($this_genomic_align->dnafrag_end, 50000033);
      ok($this_genomic_align->dnafrag_strand, 1);
      ok($this_genomic_align->level_id, 1);
      ok($this_genomic_align->cigar_line, "19M29G31M12G11M44G10M26G27M37G62M2G97M2G10M21G11M6G18M");
    } elsif ($this_genomic_align->dbID == 7279290) {
      ok($this_genomic_align->dbID, 7279290);
      ok($this_genomic_align->adaptor, $genomic_align_adaptor, "unexpected genomic_align_adaptor");
      ok($this_genomic_align->genomic_align_block_id, 3639645);
      ok($this_genomic_align->method_link_species_set_id, 2);
      ok($this_genomic_align->dnafrag_id, 34);
      ok($this_genomic_align->dnafrag_start, 66608068);
      ok($this_genomic_align->dnafrag_end, 66608528);
      ok($this_genomic_align->dnafrag_strand, 1);
      ok($this_genomic_align->level_id, 1);
      ok($this_genomic_align->cigar_line, "265MG94M13G102M");
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


exit 0;
