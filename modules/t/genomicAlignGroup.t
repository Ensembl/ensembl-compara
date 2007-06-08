#!/usr/local/ensembl/bin/perl -w

#
# Test script for Bio::EnsEMBL::Compara::GenomicAlignGroup module
#
# Written by Javier Herrero (jherrero@ebi.ac.uk)
#
# Copyright (c) 2004. EnsEMBL Team
#
# You may distribute this module under the same terms as perl itself

=head1 NAME

genomicAlignBlock.t

=head1 INSTALLATION

*_*_*_*_*_*_*_*_*_*_*_*_*_*_   W A R N I N G  _*_*_*_*_*_*_*_*_*_*_*_*_*_*

YOU MUST EDIT THE <MultiTestDB.conf> FILE BEFORE USING THIS TEST SCRIPT!!!

*_*_*_*_*_*_*_*_*_*_*_*_*_*_   W A R N I N G  _*_*_*_*_*_*_*_*_*_*_*_*_*_*

Please, read the README file for instructions.

=head1 SYNOPSIS

For running this test only:
perl -w ../../../ensembl-test/scripts/runtests.pl genomicAlignGroup.t

For running all the test scripts:
perl -w ../../../ensembl-test/scripts/runtests.pl

For running all the test scripts and cleaning the database afterwards:
perl -w ../../../ensembl-test/scripts/runtests.pl -c

=head1 DESCRIPTION

This script uses a small compara database build following the specifitions given in the MultiTestDB.conf file.

This script (as far as possible) tests all the methods defined in the
Bio::EnsEMBL::Compara::GenomicAlignGroup module.

This script includes 12 tests.

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



use strict;

BEGIN { $| = 1;  
    use Test;
    plan tests => 13;
}

use Bio::EnsEMBL::Utils::Exception qw (warning verbose);
use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::Test::TestUtils;

use Bio::EnsEMBL::Compara::GenomicAlignGroup;

# switch off the debug prints 
our $verbose = 0;

#####################################################################
## Connect to the test database using the MultiTestDB.conf file

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

my $genomic_align_group;
my $genomic_align_group_adaptor = $compara_db->get_GenomicAlignGroupAdaptor;
my $genomic_align_adaptor = $compara_db->get_GenomicAlignAdaptor;

## Data extracted from the database and used to check and test the API
my $genomic_align_group_type = "default";
my $genomic_align_group_id = $compara_db->dbc->db_handle->selectrow_array("
    SELECT group_id
    FROM genomic_align_group
    WHERE type = \"$genomic_align_group_type\" LIMIT 1");
die("No groups of type <$genomic_align_group_type> in the database. Cannot test!")
  unless ($genomic_align_group_id);

my $all_genomic_align_ids = $compara_db->dbc->db_handle->selectcol_arrayref("
    SELECT genomic_align_id
    FROM genomic_align_group
    WHERE group_id = $genomic_align_group_id");
my $genomic_align_array;
foreach my $genomic_align_id (@$all_genomic_align_ids) {
  my $genomic_align = $genomic_align_adaptor->fetch_by_dbID($genomic_align_id);
  push(@$genomic_align_array, $genomic_align);
}

##
#####################################################################
  
# 
# 1
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlignGroup::new(void) method");
  $genomic_align_group = new Bio::EnsEMBL::Compara::GenomicAlignGroup();
  ok($genomic_align_group->isa("Bio::EnsEMBL::Compara::GenomicAlignGroup"));

# 
# 2-7
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlignGroup::new(ALL) method");
  $genomic_align_group = new Bio::EnsEMBL::Compara::GenomicAlignGroup(
          -adaptor => $genomic_align_group_adaptor,
          -dbID => $genomic_align_group_id,
          -type => $genomic_align_group_type,
          -genomic_align_array => $genomic_align_array
      );
  ok($genomic_align_group->isa("Bio::EnsEMBL::Compara::GenomicAlignGroup"));
  ok($genomic_align_group->adaptor, $genomic_align_group_adaptor);
  ok($genomic_align_group->dbID, $genomic_align_group_id);
  ok($genomic_align_group->type, $genomic_align_group_type);
  ok(scalar(@{$genomic_align_group->genomic_align_array}), scalar(@{$genomic_align_array}));
  do {
    my $all_fails;
    foreach my $this_genomic_align (@{$genomic_align_group->genomic_align_array}) {
      my $fail = $this_genomic_align->dbID;
      foreach my $that_genomic_align (@$genomic_align_array) {
        if ($that_genomic_align->dbID == $this_genomic_align->dbID) {
          $fail = undef;
          last;
        }
      }
      $all_fails .= " <$fail> " if ($fail);
    }
    ok($all_fails, undef);
  };

# 
# 8
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlignGroup::adaptor method");
  $genomic_align_group = new Bio::EnsEMBL::Compara::GenomicAlignGroup();
  $genomic_align_group->adaptor($genomic_align_group_adaptor);
  ok($genomic_align_group->adaptor, $genomic_align_group_adaptor);

# 
# 9
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlignGroup::dbID method");
  $genomic_align_group = new Bio::EnsEMBL::Compara::GenomicAlignGroup();
  $genomic_align_group->dbID($genomic_align_group_id);
  ok($genomic_align_group->dbID, $genomic_align_group_id);

# 
# 10
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlignGroup::type method");
  $genomic_align_group = new Bio::EnsEMBL::Compara::GenomicAlignGroup();
  $genomic_align_group->type($genomic_align_group_type);
  ok($genomic_align_group->type, $genomic_align_group_type);

# 
# 11-12
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlignGroup::genomic_align_array method");
  $genomic_align_group = new Bio::EnsEMBL::Compara::GenomicAlignGroup();
  $genomic_align_group->genomic_align_array($genomic_align_array);
  ok(scalar(@{$genomic_align_group->genomic_align_array}), scalar(@{$genomic_align_array}));
  do {
    my $all_fails;
    foreach my $this_genomic_align (@{$genomic_align_group->genomic_align_array}) {
      my $fail = $this_genomic_align->dbID;
      foreach my $that_genomic_align (@$genomic_align_array) {
        if ($that_genomic_align->dbID == $this_genomic_align->dbID) {
          $fail = undef;
          last;
        }
      }
      $all_fails .= " <$fail> " if ($fail);
    }
    ok($all_fails, undef);
  };

# 
# 13
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlignGroup::type method");
  $genomic_align_group = new Bio::EnsEMBL::Compara::GenomicAlignGroup(
          -adaptor => $genomic_align_group_adaptor,
          -dbID => $genomic_align_group_id,
      );
  ok($genomic_align_group->type, $genomic_align_group_type,
          "Trying to get type from the database");




exit 0;
