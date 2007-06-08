#!/usr/local/ensembl/bin/perl -w

#
# Test script for Bio::EnsEMBL::Compara::DBSQL::GenomicAlignGroupAdaptor module
#
# Written by Javier Herrero (jherrero@ebi.ac.uk)
#
# Copyright (c) 2004. EnsEMBL Team
#
# You may distribute this module under the same terms as perl itself

=head1 NAME

genomicAlignBlockAdaptor.t

=head1 INSTALLATION

*_*_*_*_*_*_*_*_*_*_*_*_*_*_   W A R N I N G  _*_*_*_*_*_*_*_*_*_*_*_*_*_*

YOU MUST EDIT THE <MultiTestDB.conf> FILE BEFORE USING THIS TEST SCRIPT!!!

*_*_*_*_*_*_*_*_*_*_*_*_*_*_   W A R N I N G  _*_*_*_*_*_*_*_*_*_*_*_*_*_*

Please, read the README file for instructions.

=head1 SYNOPSIS

For running this test only:
perl -w ../../../ensembl-test/scripts/runtests.pl genomicAlignGroupAdaptor.t

For running all the test scripts:
perl -w ../../../ensembl-test/scripts/runtests.pl

For running all the test scripts and cleaning the database afterwards:
perl -w ../../../ensembl-test/scripts/runtests.pl -c

=head1 DESCRIPTION

This script uses a small compara database build following the specifitions given in the MultiTestDB.conf file.

This script (hopefully and as far as possible) tests all the methods defined in the
Bio::EnsEMBL::Compara::DBSQL::GenomicAlignGroupAdaptor module.

This script includes 48 tests.

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
    plan tests => 35;
}

use Bio::EnsEMBL::Utils::Exception qw (warning verbose);
use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::Test::TestUtils;

use Bio::EnsEMBL::Compara::GenomicAlignGroup;

#####################################################################
## Connect to the test database using the MultiTestDB.conf file

my $multi = Bio::EnsEMBL::Test::MultiTestDB->new( "multi" );
my $compara_db_adaptor = $multi->get_DBAdaptor( "compara" );
my $genome_db_adaptor = $compara_db_adaptor->get_GenomeDBAdaptor();

my $species = [
        "homo_sapiens",
        "mus_musculus",
        "rattus_norvegicus",
        "gallus_gallus",
	 "bos_taurus",
	"canis_familiaris",
	"macaca_mulatta",
	"monodelphis_domestica",
	"ornithorhynchus_anatinus",
	"pan_troglodytes",
    ];

my $species_db;
my $species_db_adaptor;
my $species_gdb;
## Connect to core DB specified in the MultiTestDB.conf file
foreach my $this_species (@$species) {
  $species_db->{$this_species} = Bio::EnsEMBL::Test::MultiTestDB->new($this_species);
  die if (!$species_db->{$this_species});
  $species_db_adaptor->{$this_species} = $species_db->{$this_species}->get_DBAdaptor('core');
  $species_gdb->{$this_species} = $genome_db_adaptor->fetch_by_name_assembly(
          $species_db_adaptor->{$this_species}->get_MetaContainer->get_Species->binomial,
          $species_db_adaptor->{$this_species}->get_CoordSystemAdaptor->fetch_all->[0]->version
      );
  $species_gdb->{$this_species}->db_adaptor($species_db_adaptor->{$this_species});
}

##
#####################################################################

# switch off the debug prints 
our $verbose = 0;

my $genomic_align_group;
my $all_genomic_align_group;
my $genomic_align_group_adaptor = $compara_db_adaptor->get_GenomicAlignGroupAdaptor;
my $genomic_align_adaptor = $compara_db_adaptor->get_GenomicAlignAdaptor;

## Data extracted from the database and used to check and test the API
my $genomic_align_group_type = "default";
my $genomic_align_group_id = $compara_db_adaptor->dbc->db_handle->selectrow_array("
    SELECT group_id
    FROM genomic_align_group
    WHERE type = \"$genomic_align_group_type\" LIMIT 1");
die("No groups of type <$genomic_align_group_type> in the database. Cannot test!")
  unless ($genomic_align_group_id);

my $all_genomic_align_ids = $compara_db_adaptor->dbc->db_handle->selectcol_arrayref("
    SELECT genomic_align_id
    FROM genomic_align_group
    WHERE group_id = $genomic_align_group_id");
my $genomic_align_array;
my $genomic_align_1_id = shift(@$all_genomic_align_ids);
my $genomic_align_1 = $genomic_align_adaptor->fetch_by_dbID($genomic_align_1_id);
push(@$genomic_align_array, $genomic_align_1);
foreach my $genomic_align_id (@$all_genomic_align_ids) {
  my $genomic_align = $genomic_align_adaptor->fetch_by_dbID($genomic_align_id);
  push(@$genomic_align_array, $genomic_align);
}
  
# 
# 1-6
# 
debug("Test Bio::EnsEMBL::Compara::DBSQL::GenomicAlignGroupAdaptor::fetch_by_dbID");
  $genomic_align_group = $genomic_align_group_adaptor->fetch_by_dbID($genomic_align_group_id);
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
# 7-14
# 
debug("Test Bio::EnsEMBL::Compara::DBSQL::GenomicAlignGroupAdaptor::fetch_all_by_GenomicAlign [1]");
  $all_genomic_align_group = $genomic_align_group_adaptor->fetch_all_by_GenomicAlign($genomic_align_1);
  ok(scalar(@$all_genomic_align_group), 1);
  $genomic_align_group = $all_genomic_align_group->[0];
  ok($genomic_align_group->isa("Bio::EnsEMBL::Compara::GenomicAlignGroup"));
  ok($genomic_align_group->adaptor, $genomic_align_group_adaptor);
  ok($genomic_align_group->dbID, $genomic_align_group_id);
  ok($genomic_align_group->type, $genomic_align_group_type);
  ok(scalar(@{$genomic_align_group->genomic_align_array}), scalar(@{$genomic_align_array}));
  do {
    my $all_fails;
    my $has_original_GA_been_found = 0;
    foreach my $this_genomic_align (@{$genomic_align_group->genomic_align_array}) {
      my $fail = $this_genomic_align->dbID;
      if ($this_genomic_align->dbID == $genomic_align_1->dbID) {
        $has_original_GA_been_found = 1;
        ok($genomic_align_group->dbID, $genomic_align_1->genomic_align_group_by_type($genomic_align_group->type)->dbID);
      }
      foreach my $that_genomic_align (@$genomic_align_array) {
        if ($that_genomic_align->dbID == $this_genomic_align->dbID) {
          $fail = undef;
          last;
        }
      }
      $all_fails .= " <$fail> " if ($fail);
    };
    $all_fails .= " Cannot retrieve original GenomicAlign object! " if (!$has_original_GA_been_found);
    ok($all_fails, undef);
  };

# 
# 15-21
# 
debug("Test Bio::EnsEMBL::Compara::DBSQL::GenomicAlignGroupAdaptor::fetch_all_by_genomic_align_id [1]");
  $all_genomic_align_group = $genomic_align_group_adaptor->fetch_all_by_genomic_align_id($genomic_align_1_id);
  ok(scalar(@$all_genomic_align_group), 1);
  $genomic_align_group = $all_genomic_align_group->[0];
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
# 22-28
# 
debug("Test Bio::EnsEMBL::Compara::DBSQL::GenomicAlignGroupAdaptor::fetch_by_GenomicAlign_type [1]");
  $genomic_align_group = $genomic_align_group_adaptor->fetch_by_GenomicAlign_type($genomic_align_1,
          $genomic_align_group_type);
  ok($genomic_align_group->isa("Bio::EnsEMBL::Compara::GenomicAlignGroup"));
  ok($genomic_align_group->adaptor, $genomic_align_group_adaptor);
  ok($genomic_align_group->dbID, $genomic_align_group_id);
  ok($genomic_align_group->type, $genomic_align_group_type);
  ok(scalar(@{$genomic_align_group->genomic_align_array}), scalar(@{$genomic_align_array}));
  do {
    my $all_fails;
    my $has_original_GA_been_found = 0;
    foreach my $this_genomic_align (@{$genomic_align_group->genomic_align_array}) {
      my $fail = $this_genomic_align->dbID;
      if ($this_genomic_align->dbID == $genomic_align_1->dbID) {
        $has_original_GA_been_found = 1;
        ok($genomic_align_group->dbID, $genomic_align_1->genomic_align_group_by_type($genomic_align_group->type)->dbID);
      }
      foreach my $that_genomic_align (@$genomic_align_array) {
        if ($that_genomic_align->dbID == $this_genomic_align->dbID) {
          $fail = undef;
          last;
        }
      }
      $all_fails .= " <$fail> " if ($fail);
    }
    $all_fails .= " Cannot retrieve original GenomicAlign object! " if (!$has_original_GA_been_found);
    ok($all_fails, undef);
  };


# 
# 29-35
# 
debug("Test Bio::EnsEMBL::Compara::DBSQL::GenomicAlignGroupAdaptor::fetch_by_GenomicAlign_and_type [2]");
  $genomic_align_group = $genomic_align_group_adaptor->fetch_by_genomic_align_id_type(
          $genomic_align_1_id,
          $genomic_align_group_type
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


debug("Test Bio::EnsEMBL::Compara::DBSQL::GenomicAlignGroupAdaptor::store");
  $genomic_align_group = $genomic_align_group_adaptor->fetch_by_dbID($genomic_align_group_id);
  $multi->hide("compara", "genomic_align_group");
  $genomic_align_group->dbID(0);
  $genomic_align_group_adaptor->use_autoincrement(0);
  $genomic_align_group_adaptor->store($genomic_align_group);
  ok($genomic_align_group->dbID,
      $genomic_align_group->genomic_align_array->[0]->method_link_species_set_id*10000000000+1,
      "Assignation of a group_id based on the method_link_species_set_id * 10^10");
  $multi->restore("compara", "genomic_align_group");

exit 0;
