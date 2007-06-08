#!/usr/local/ensembl/bin/perl -w

#
# Test script for Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor module
#
# Written by Javier Herrero (jherrero@ebi.ac.uk)
#
# Copyright (c) 2004. EnsEMBL Team
#
# You may distribute this module under the same terms as perl itself

=head1 NAME

methodLinkSpeciesSetAdaptor.t

=head1 SYNOPSIS

For running this test only:
perl -w ../../../ensembl-test/scripts/runtests.pl methodLinkSpeciesSetAdaptor.t

For running all the test scripts:
perl -w ../../../ensembl-test/scripts/runtests.pl

=head1 DESCRIPTION

This script uses a small compara database build following the specifitions given in the MultiTestDB.conf file.

This script (as far as possible) tests all the methods defined in the
Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor module.

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
  plan tests => 65;
}

use Bio::EnsEMBL::Utils::Exception qw (warning verbose);
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::Test::TestUtils;

# switch off the debug prints
our $verbose = 0;

# switch off the deprecated warning messages
verbose("WARNING");

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
  
my $genome_db_adaptor = $compara_db->get_GenomeDBAdaptor();
  
my $method_link_species_set_adaptor;
my $method_link_species_sets;
my $method_link_species_set;
my $species;
my $is_test_ok;
my $blastz_net_method_link_id = 1;

my $all_mlss;
my ($human_genome_db_id) = $compara_db->dbc->db_handle->selectrow_array("
    SELECT genome_db_id
    FROM genome_db
    WHERE name = 'Homo sapiens'");

my $all_rows = $compara_db->dbc->db_handle->selectall_arrayref("
    SELECT mlss.method_link_species_set_id, ml.method_link_id, ml.type, ml.class,
        GROUP_CONCAT(gdb.name ORDER BY gdb.name),
        GROUP_CONCAT(gdb.genome_db_id ORDER BY gdb.genome_db_id)
    FROM method_link ml, method_link_species_set mlss, species_set ss, genome_db gdb
    WHERE mlss.method_link_id = ml.method_link_id
      AND mlss.species_set_id = ss.species_set_id
      AND ss.genome_db_id = gdb.genome_db_id
    GROUP BY mlss.method_link_species_set_id");

foreach my $row (@$all_rows) {
  $all_mlss->{$row->[0]} = {
          method_link_id => $row->[1],
          type => $row->[2],
          class => $row->[3],
          species_set => $row->[4],
          gdbid_set => $row->[5]
      }
}

# 
# 1. Check premises
# 
debug( "Check premises" );
ok(defined($multi) and defined($homo_sapiens) and defined($mus_musculus) and defined($rattus_norvegicus)
    and defined($compara_db));


# 
# 2. Check adaptor
# 
debug("Check Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor");
$method_link_species_set_adaptor = $compara_db->get_MethodLinkSpeciesSetAdaptor();
ok(defined($method_link_species_set_adaptor)
    and $method_link_species_set_adaptor->isa("Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor"));

# 
# 3-4. Test fetch_all
# 
debug("Test Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor::fetch_all");
  $method_link_species_sets = $method_link_species_set_adaptor->fetch_all;
  ok(scalar(@{$method_link_species_sets}), values(%$all_mlss));
  @$method_link_species_sets = sort {$a->dbID <=> $b->dbID } @$method_link_species_sets;
  $is_test_ok = 1;
  foreach my $this_method_link_species_set (@$method_link_species_sets) {
    $is_test_ok = 0 if (!$this_method_link_species_set->isa("Bio::EnsEMBL::Compara::MethodLinkSpeciesSet"));
    $species = join(",", sort map {$_->name} @{$this_method_link_species_set->species_set});
    if (defined($all_mlss->{$this_method_link_species_set->dbID})) {
      $is_test_ok = 2 if ($this_method_link_species_set->method_link_id !=
          $all_mlss->{$this_method_link_species_set->dbID}->{method_link_id});
      $is_test_ok = 3 if ($this_method_link_species_set->method_link_type ne 
          $all_mlss->{$this_method_link_species_set->dbID}->{type});
      $is_test_ok = 4 if ($this_method_link_species_set->method_link_class ne 
          $all_mlss->{$this_method_link_species_set->dbID}->{class});
      $is_test_ok = 5 if ($species ne 
          $all_mlss->{$this_method_link_species_set->dbID}->{species_set});
    } else {
      $is_test_ok = 0;
      print STDERR "\n\n ", $this_method_link_species_set->dbID, ". $species\n";
    }
  }
  ok($is_test_ok, 1);


# 
# 5. Test fetch_by_dbID
# 
debug("Test Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor::fetch_by_dbID [1]");
  my $this_method_link_species_set_id = [keys(%$all_mlss)]->[0];
  $method_link_species_set = $method_link_species_set_adaptor->fetch_by_dbID($this_method_link_species_set_id);
  $is_test_ok = 1;
  $is_test_ok = 2 if (!UNIVERSAL::isa($method_link_species_set, "Bio::EnsEMBL::Compara::MethodLinkSpeciesSet"));
  $is_test_ok = 3 if ($method_link_species_set->dbID != $this_method_link_species_set_id);
  $is_test_ok = 4 if ($method_link_species_set->method_link_id !=
      $all_mlss->{$this_method_link_species_set_id}->{method_link_id});
  $is_test_ok = 5 if ($method_link_species_set->method_link_type ne
      $all_mlss->{$this_method_link_species_set_id}->{type});
  $is_test_ok = 6 if ($method_link_species_set->method_link_class ne
      $all_mlss->{$this_method_link_species_set_id}->{class});
  $species = join(",", sort map {$_->name} @{$method_link_species_set->species_set});
  $is_test_ok = 0 if ($species ne $all_mlss->{$this_method_link_species_set_id}->{species_set});
  ok($is_test_ok, 1);


# 
# 6. Test fetch_by_dbID
# 
debug("Test Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor::fetch_by_dbID [2]");
  $method_link_species_set = $method_link_species_set_adaptor->fetch_by_dbID(-1);
  ok(!$method_link_species_set);


# 
# 11-12. Test fetch_all_by_method_link_type [1]
# 
debug("Test Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor::fetch_all_by_method_link_type [1]");
  my $this_type = [map {$_->{type}} values(%$all_mlss)]->[0];
  $method_link_species_sets = $method_link_species_set_adaptor->fetch_all_by_method_link_type($this_type);
  ok(scalar(@{$method_link_species_sets}), grep {$_->{type} eq $this_type} values(%$all_mlss));
  @$method_link_species_sets = sort {$a->dbID <=> $b->dbID } @$method_link_species_sets;
  $is_test_ok = 1;
  foreach my $this_method_link_species_set (@$method_link_species_sets) {
    $is_test_ok = 0 if (!$this_method_link_species_set->isa("Bio::EnsEMBL::Compara::MethodLinkSpeciesSet"));
    $species = join(",", sort map {$_->name} @{$this_method_link_species_set->species_set});
    if (defined($all_mlss->{$this_method_link_species_set->dbID})) {
      $is_test_ok = 2 if ($this_method_link_species_set->method_link_id !=
          $all_mlss->{$this_method_link_species_set->dbID}->{method_link_id});
      $is_test_ok = 3 if ($this_method_link_species_set->method_link_type ne 
          $all_mlss->{$this_method_link_species_set->dbID}->{type});
      $is_test_ok = 4 if ($this_method_link_species_set->method_link_class ne 
          $all_mlss->{$this_method_link_species_set->dbID}->{class});
      $is_test_ok = 5 if ($species ne 
          $all_mlss->{$this_method_link_species_set->dbID}->{species_set});
    } else {
      $is_test_ok = 0;
      print STDERR "\n\n ", $this_method_link_species_set->dbID, ". $species\n";
    }
  }
  ok($is_test_ok, 1);


# 
# 13-14. Test fetch_all_by_method_link_type [2]
# 
debug("Test Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor::fetch_all_by_method_link_type [2]");
  my $current_verbose = verbose();
  verbose(0);
  $method_link_species_sets = $method_link_species_set_adaptor->fetch_all_by_method_link_type("NOT_AN_EXISTING_METHOD_LINK");
  verbose($current_verbose);
  ok($method_link_species_sets);
  ok(scalar(@{$method_link_species_sets}), 0);


# 
# 15-16. Test fetch_all_by_method_link_id [1]
# 
debug("Test Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor::fetch_all_by_method_link_id [1]");
  my $this_method_link_id = [map {$_->{method_link_id}} values(%$all_mlss)]->[0];
  $method_link_species_sets = $method_link_species_set_adaptor->fetch_all_by_method_link_id($this_method_link_id);
  ok(scalar(@{$method_link_species_sets}), grep {$_->{type} eq $this_type} values(%$all_mlss));
  @$method_link_species_sets = sort {$a->dbID <=> $b->dbID } @$method_link_species_sets;
  $is_test_ok = 1;
  foreach my $this_method_link_species_set (@$method_link_species_sets) {
    $is_test_ok = 0 if (!$this_method_link_species_set->isa("Bio::EnsEMBL::Compara::MethodLinkSpeciesSet"));
    $species = join(",", sort map {$_->name} @{$this_method_link_species_set->species_set});
    if (defined($all_mlss->{$this_method_link_species_set->dbID})) {
      $is_test_ok = 2 if ($this_method_link_species_set->method_link_id !=
          $all_mlss->{$this_method_link_species_set->dbID}->{method_link_id});
      $is_test_ok = 3 if ($this_method_link_species_set->method_link_type ne 
          $all_mlss->{$this_method_link_species_set->dbID}->{type});
      $is_test_ok = 4 if ($this_method_link_species_set->method_link_class ne 
          $all_mlss->{$this_method_link_species_set->dbID}->{class});
      $is_test_ok = 5 if ($species ne 
          $all_mlss->{$this_method_link_species_set->dbID}->{species_set});
    } else {
      $is_test_ok = 0;
      print STDERR "\n\n ", $this_method_link_species_set->dbID, ". $species\n";
    }
  }
  ok($is_test_ok, 1);


# 
# 17-18. Test fetch_all_by_method_link_id [2]
# 
debug("Test Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor::fetch_all_by_method_link_id [2]");
  $method_link_species_sets = $method_link_species_set_adaptor->fetch_all_by_method_link_id(-1);
  ok($method_link_species_sets);
  ok(scalar(@{$method_link_species_sets}), 0);


# 
# 23. Test fetch_all_by_GenomeDB [1]
# 
my $species_name = [split(",", [map {$_->{species_set}} values(%$all_mlss)]->[0])]->[0];
debug("Test Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor::fetch_all_by_GenomeDB [1]");
  $method_link_species_sets = $method_link_species_set_adaptor->fetch_all_by_GenomeDB(
          $genome_db_adaptor->fetch_by_name_assembly($species_name)
      );
  ok(scalar(@{$method_link_species_sets}), grep {$_->{species_set} =~ /$species_name/} values(%$all_mlss));
  @$method_link_species_sets = sort {$a->dbID <=> $b->dbID } @$method_link_species_sets;
  $is_test_ok = 1;
  foreach my $this_method_link_species_set (@$method_link_species_sets) {
    $is_test_ok = 0 if (!$this_method_link_species_set->isa("Bio::EnsEMBL::Compara::MethodLinkSpeciesSet"));
    $species = join(",", sort map {$_->name} @{$this_method_link_species_set->species_set});
    if (defined($all_mlss->{$this_method_link_species_set->dbID})) {
      $is_test_ok = 2 if ($this_method_link_species_set->method_link_id !=
          $all_mlss->{$this_method_link_species_set->dbID}->{method_link_id});
      $is_test_ok = 3 if ($this_method_link_species_set->method_link_type ne 
          $all_mlss->{$this_method_link_species_set->dbID}->{type});
      $is_test_ok = 4 if ($this_method_link_species_set->method_link_class ne 
          $all_mlss->{$this_method_link_species_set->dbID}->{class});
      $is_test_ok = 5 if ($species ne 
          $all_mlss->{$this_method_link_species_set->dbID}->{species_set});
    } else {
      $is_test_ok = 0;
      print STDERR "\n\n ", $this_method_link_species_set->dbID, ". $species\n";
    }
  }
  ok($is_test_ok, 1);


# 
# 23. Test fetch_all_by_GenomeDB [3]
# 
debug("Test Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor::fetch_all_by_GenomeDB [2]");
  $method_link_species_sets = eval {
          $method_link_species_set_adaptor->fetch_all_by_GenomeDB("THIS IS A WRONG ARGUMENT");
      };
  ok($method_link_species_sets, undef, "Testing failure");


# 
# 25-26. Test fetch_all_by_genome_db_id [1]
# 
debug("Test Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor::fetch_all_by_genome_db_id [1]");
  $method_link_species_sets = $method_link_species_set_adaptor->fetch_all_by_genome_db_id(
      $genome_db_adaptor->fetch_by_name_assembly($species_name)->dbID);
  ok(scalar(@{$method_link_species_sets}), grep {$_->{species_set} =~ /$species_name/} values(%$all_mlss));


# 
# 27-28. Test fetch_all_by_genome_db_id [2]
# 
debug("Test Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor::fetch_all_by_genome_db_id [2]");
  $method_link_species_sets = $method_link_species_set_adaptor->fetch_all_by_genome_db_id(-1);
  ok($method_link_species_sets);
  ok(scalar(@{$method_link_species_sets}), 0);

debug("Test Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor::fetch_all_by_method_link_id_GenomeDB [2]");
  $method_link_species_sets = $method_link_species_set_adaptor->fetch_all_by_method_link_id_GenomeDB(
          $blastz_net_method_link_id,
          $genome_db_adaptor->fetch_by_dbID($human_genome_db_id)
      );
  ok(scalar(@{$method_link_species_sets}), 9);

debug("Test Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor::fetch_all_by_method_link_id_genome_db_id");
  $method_link_species_sets = $method_link_species_set_adaptor->fetch_all_by_method_link_id_genome_db_id(
          $blastz_net_method_link_id,
          $human_genome_db_id);
  ok(scalar(@{$method_link_species_sets}), 9);

# 
# 29. Test fetch_all_by_genome_db_id [2]
# 
debug("Test Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor::fetch_all_by_method_link_type_GenomeDB [2]");
  $method_link_species_sets = $method_link_species_set_adaptor->fetch_all_by_method_link_type_GenomeDB(
          "BLASTZ_NET",
          $genome_db_adaptor->fetch_by_dbID($human_genome_db_id)
      );
  ok(scalar(@{$method_link_species_sets}), 9);

# 
# 30. Test fetch_all_by_genome_db_id [2]
# 
debug("Test Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor::fetch_all_by_method_link_type_genome_db_id");
  $method_link_species_sets = $method_link_species_set_adaptor->fetch_all_by_method_link_type_genome_db_id(
          "BLASTZ_NET",
          $human_genome_db_id);
  ok(scalar(@{$method_link_species_sets}), 9);

# 
# 31. Test fetch_by_method_link_type_GenomeDBs
# 
debug("Test Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor::fetch_by_method_link_type_genome_db_ids [1]");
  $method_link_species_set = $method_link_species_set_adaptor->fetch_by_method_link_type_GenomeDBs(
          $all_mlss->{$this_method_link_species_set_id}->{type},
          [map {$genome_db_adaptor->fetch_by_dbID($_)} split(",",
              $all_mlss->{$this_method_link_species_set_id}->{gdbid_set})]
      );
  ok($method_link_species_set->isa("Bio::EnsEMBL::Compara::MethodLinkSpeciesSet"));
  ok($method_link_species_set->dbID, $this_method_link_species_set_id);
  ok($method_link_species_set->method_link_id,
      $all_mlss->{$this_method_link_species_set_id}->{method_link_id});
  ok($method_link_species_set->method_link_type,
      $all_mlss->{$this_method_link_species_set_id}->{type});
  ok($method_link_species_set->method_link_class,
      $all_mlss->{$this_method_link_species_set_id}->{class});
  $species = join(",", sort map {$_->name} @{$method_link_species_set->species_set});
  ok($species, $all_mlss->{$this_method_link_species_set_id}->{species_set});


# 
# 31. Test fetch_by_method_link_type_genome_db_ids
# 
debug("Test Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor::fetch_by_method_link_type_genome_db_ids [1]");
  $method_link_species_set = $method_link_species_set_adaptor->fetch_by_method_link_type_genome_db_ids(
          $all_mlss->{$this_method_link_species_set_id}->{type},
          [map {$genome_db_adaptor->fetch_by_dbID($_)->dbID} split(",",
              $all_mlss->{$this_method_link_species_set_id}->{gdbid_set})]
      );
  ok($method_link_species_set->isa("Bio::EnsEMBL::Compara::MethodLinkSpeciesSet"));
  ok($method_link_species_set->dbID, $this_method_link_species_set_id);
  ok($method_link_species_set->method_link_id,
      $all_mlss->{$this_method_link_species_set_id}->{method_link_id});
  ok($method_link_species_set->method_link_type,
      $all_mlss->{$this_method_link_species_set_id}->{type});
  ok($method_link_species_set->method_link_class,
      $all_mlss->{$this_method_link_species_set_id}->{class});
  $species = join(",", sort map {$_->name} @{$method_link_species_set->species_set});
  ok($species, $all_mlss->{$this_method_link_species_set_id}->{species_set});


debug("Test Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor::fetch_by_method_link_id_genome_db_ids [1]");
  $method_link_species_set = $method_link_species_set_adaptor->fetch_by_method_link_id_GenomeDBs(
          $all_mlss->{$this_method_link_species_set_id}->{method_link_id},
          [map {$genome_db_adaptor->fetch_by_dbID($_)} split(",",
              $all_mlss->{$this_method_link_species_set_id}->{gdbid_set})]
      );
  ok($method_link_species_set->isa("Bio::EnsEMBL::Compara::MethodLinkSpeciesSet"));
  ok($method_link_species_set->dbID, $this_method_link_species_set_id);
  ok($method_link_species_set->method_link_id,
      $all_mlss->{$this_method_link_species_set_id}->{method_link_id});
  ok($method_link_species_set->method_link_type,
      $all_mlss->{$this_method_link_species_set_id}->{type});
  ok($method_link_species_set->method_link_class,
      $all_mlss->{$this_method_link_species_set_id}->{class});
  $species = join(",", sort map {$_->name} @{$method_link_species_set->species_set});
  ok($species, $all_mlss->{$this_method_link_species_set_id}->{species_set});


debug("Test Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor::fetch_by_method_link_id_genome_db_ids [1]");
  $method_link_species_set = $method_link_species_set_adaptor->fetch_by_method_link_id_genome_db_ids(
          $all_mlss->{$this_method_link_species_set_id}->{method_link_id},
          [map {$genome_db_adaptor->fetch_by_dbID($_)->dbID} split(",",
              $all_mlss->{$this_method_link_species_set_id}->{gdbid_set})]
      );
  ok($method_link_species_set->isa("Bio::EnsEMBL::Compara::MethodLinkSpeciesSet"));
  ok($method_link_species_set->dbID, $this_method_link_species_set_id);
  ok($method_link_species_set->method_link_id,
      $all_mlss->{$this_method_link_species_set_id}->{method_link_id});
  ok($method_link_species_set->method_link_type,
      $all_mlss->{$this_method_link_species_set_id}->{type});
  ok($method_link_species_set->method_link_class,
      $all_mlss->{$this_method_link_species_set_id}->{class});
  $species = join(",", sort map {$_->name} @{$method_link_species_set->species_set});
  ok($species, $all_mlss->{$this_method_link_species_set_id}->{species_set});


# 
# 34. Check new method
# 
debug( "Check Bio::EnsEMBL::Compara::MethodLinkSpeciesSet::new method [1]" );
  $method_link_species_set = new Bio::EnsEMBL::Compara::MethodLinkSpeciesSet(
        -dbID => $this_method_link_species_set_id,
        -adaptor => $method_link_species_set_adaptor,
        -method_link_id => $all_mlss->{$this_method_link_species_set_id}->{method_link_id},
        -method_link_type => $all_mlss->{$this_method_link_species_set_id}->{type},
        -method_link_class => $all_mlss->{$this_method_link_species_set_id}->{class},
        -species_set => [map {$genome_db_adaptor->fetch_by_dbID($_)} split(",",
              $all_mlss->{$this_method_link_species_set_id}->{gdbid_set})],
    );
  ok($method_link_species_set->isa("Bio::EnsEMBL::Compara::MethodLinkSpeciesSet"));
  ok($method_link_species_set->dbID, $this_method_link_species_set_id);
  ok($method_link_species_set->method_link_id,
      $all_mlss->{$this_method_link_species_set_id}->{method_link_id});
  ok($method_link_species_set->method_link_type,
      $all_mlss->{$this_method_link_species_set_id}->{type});
  ok($method_link_species_set->method_link_class,
      $all_mlss->{$this_method_link_species_set_id}->{class});
  $species = join(",", sort map {$_->name} @{$method_link_species_set->species_set});
  ok($species, $all_mlss->{$this_method_link_species_set_id}->{species_set});


# 
# 35-36. Check store method with already existing entry
# 
debug( "Check Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSet::store method [1]" );
  $method_link_species_set_adaptor->store($method_link_species_set);
  ok($method_link_species_set->dbID, $this_method_link_species_set_id);
  ok(scalar(@{$method_link_species_set_adaptor->fetch_all}), values(%$all_mlss));


# 
# 37. Check new method(2)
# 
debug( "Check Bio::EnsEMBL::Compara::MethodLinkSpeciesSet::new method [2]" );
  $method_link_species_set = new Bio::EnsEMBL::Compara::MethodLinkSpeciesSet(
        -method_link_id => $blastz_net_method_link_id,
        -method_link_type => "BLASTZ_NET",
        -method_link_class => "GenomicAlignBlock.pairwise_alignment",
        -species_set => [
            $genome_db_adaptor->fetch_by_name_assembly("Gallus gallus"),
            $genome_db_adaptor->fetch_by_name_assembly("Mus musculus")],
        -max_alignment_length => 1000,
    );
  $is_test_ok = 1;
  ok($method_link_species_set->isa("Bio::EnsEMBL::Compara::MethodLinkSpeciesSet"));
  ok($method_link_species_set->method_link_id, $blastz_net_method_link_id);
  ok($method_link_species_set->method_link_type, "BLASTZ_NET");
  ok($method_link_species_set->method_link_class, "GenomicAlignBlock.pairwise_alignment");
  $species = join(" - ", sort map {$_->name} @{$method_link_species_set->species_set});
  ok($species, "Gallus gallus - Mus musculus");


# 
# 38. Check store method with a new entry
# 
debug( "Check Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSet::store method [2]" );
  $multi->save("compara", "method_link_species_set", "species_set", "meta");
  $method_link_species_set_adaptor->store($method_link_species_set);
  ok(scalar(@{$method_link_species_set_adaptor->fetch_all}), values(%$all_mlss) + 1);


# 
# 39. Check delete method
# 
debug( "Check Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSet::delete method" );
  $method_link_species_set_adaptor->delete($method_link_species_set->dbID);
  ok(scalar(@{$method_link_species_set_adaptor->fetch_all}), values(%$all_mlss));
  $method_link_species_set_adaptor->store($method_link_species_set);
  ok(scalar(@{$method_link_species_set_adaptor->fetch_all}), values(%$all_mlss) + 1);
  $multi->restore("compara", "method_link_species_set", "species_set", "meta");
  ok(scalar(@{$method_link_species_set_adaptor->fetch_all}), values(%$all_mlss));

