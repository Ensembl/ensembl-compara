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

This script includes 41 tests.

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
	plan tests => 41;
}

use Bio::EnsEMBL::Utils::Exception qw (warning);
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::Test::TestUtils;

# switch off the debug prints
our $verbose = 0;

my $multi = Bio::EnsEMBL::Test::MultiTestDB->new( "multi" );
my $homo_sapiens = Bio::EnsEMBL::Test::MultiTestDB->new("homo_sapiens");
my $mus_musculus = Bio::EnsEMBL::Test::MultiTestDB->new("mus_musculus");
my $rattus_norvegicus = Bio::EnsEMBL::Test::MultiTestDB->new("rattus_norvegicus");

my $compara_db = $multi->get_DBAdaptor( "compara" );
  
my $genome_db_adaptor = $compara_db->get_GenomeDBAdaptor();
  
my $method_link_species_set_adaptor;
my $method_link_species_sets;
my $method_link_species_set;
my $species;
my $is_test_ok;

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
  ok(scalar(@{$method_link_species_sets}), 5);
  @$method_link_species_sets = sort {$a->dbID <=> $b->dbID } @$method_link_species_sets;
  $is_test_ok = 1;
  foreach my $this_method_link_species_set (@$method_link_species_sets) {
    $is_test_ok = 0 if (!$this_method_link_species_set->isa("Bio::EnsEMBL::Compara::MethodLinkSpeciesSet"));
    $species = join(" - ", map {$_->name} @{$this_method_link_species_set->species_set});
    if ($this_method_link_species_set->dbID == 72) {
      $is_test_ok = 0 if ($this_method_link_species_set->method_link_id != 1);
      $is_test_ok = 0 if ($this_method_link_species_set->method_link_type ne "BLASTZ_NET");
      $is_test_ok = 0 if ($species ne "Homo sapiens - Rattus norvegicus");
    } elsif ($this_method_link_species_set->dbID == 28) {
      $is_test_ok = 0 if ($this_method_link_species_set->method_link_id != 201);
      $is_test_ok = 0 if ($this_method_link_species_set->method_link_type ne "ENSEMBL_ORTHOLOGUES");
      $is_test_ok = 0 if ($species ne "Homo sapiens - Rattus norvegicus");
    } elsif ($this_method_link_species_set->dbID == 68) {
      $is_test_ok = 0 if ($this_method_link_species_set->method_link_id != 301);
      $is_test_ok = 0 if ($this_method_link_species_set->method_link_type ne "FAMILY");
      $is_test_ok = 0 if ($species !~ /^Homo sapiens - Mus musculus - Rattus norvegicus - Fugu rubripes/);
    } elsif ($this_method_link_species_set->dbID == 30) {
      $is_test_ok = 0 if ($this_method_link_species_set->method_link_id != 201);
      $is_test_ok = 0 if ($this_method_link_species_set->method_link_type ne "ENSEMBL_ORTHOLOGUES");
      $is_test_ok = 0 if ($species ne "Homo sapiens - Gallus gallus");
    } elsif ($this_method_link_species_set->dbID == 71) {
      $is_test_ok = 0 if ($this_method_link_species_set->method_link_id != 1);
      $is_test_ok = 0 if ($this_method_link_species_set->method_link_type ne "BLASTZ_NET");
      $is_test_ok = 0 if ($species ne "Homo sapiens - Gallus gallus");
    } else {
      $is_test_ok = 0;
      print STDERR "\n\n ", $this_method_link_species_set->dbID, ". $species\n";
    }
  }
  ok($is_test_ok);


# 
# 5. Test fetch_by_dbID
# 
debug("Test Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor::fetch_by_dbID [1]");
  $method_link_species_set = $method_link_species_set_adaptor->fetch_by_dbID(72);
  $is_test_ok = 1;
  $is_test_ok = 0 if (!$method_link_species_set->isa("Bio::EnsEMBL::Compara::MethodLinkSpeciesSet"));
  $is_test_ok = 0 if ($method_link_species_set->dbID != 72);
  $is_test_ok = 0 if ($method_link_species_set->method_link_id != 1);
  $is_test_ok = 0 if ($method_link_species_set->method_link_type ne "BLASTZ_NET");
  $species = join(" - ", map {$_->name} @{$method_link_species_set->species_set});
  $is_test_ok = 0 if ($species ne "Homo sapiens - Rattus norvegicus");
  ok($is_test_ok);


# 
# 6. Test fetch_by_dbID
# 
debug("Test Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor::fetch_by_dbID [2]");
  $method_link_species_set = $method_link_species_set_adaptor->fetch_by_dbID(-1);
  ok(!$method_link_species_set);


# 
# 7-8. Test fetch_all_by_method_link [1]
# 
debug("Test Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor::fetch_all_by_method_link [1]");
  $method_link_species_sets = $method_link_species_set_adaptor->fetch_all_by_method_link("BLASTZ_NET");
  ok(scalar(@{$method_link_species_sets}), 2);
  @$method_link_species_sets = sort {$a->dbID <=> $b->dbID } @$method_link_species_sets;
  $is_test_ok = 1;
  foreach my $this_method_link_species_set (@$method_link_species_sets) {
    $is_test_ok = 0 if (!$this_method_link_species_set->isa("Bio::EnsEMBL::Compara::MethodLinkSpeciesSet"));
    $is_test_ok = 0 if ($this_method_link_species_set->method_link_id != 1);
    $is_test_ok = 0 if ($this_method_link_species_set->method_link_type ne "BLASTZ_NET");
    $species = join(" - ", map {$_->name} @{$this_method_link_species_set->species_set});
    if ($this_method_link_species_set->dbID == 72) {
      $is_test_ok = 0 if ($species ne "Homo sapiens - Rattus norvegicus");
    } elsif ($this_method_link_species_set->dbID == 71) {
      $is_test_ok = 0 if ($species ne "Homo sapiens - Gallus gallus");
    } else {
      $is_test_ok = 0;
    }
  }
  ok($is_test_ok);


# 
# 9-10. Test fetch_all_by_method_link [2]
# 
debug("Test Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor::fetch_all_by_method_link [2]");
  $method_link_species_sets = $method_link_species_set_adaptor->fetch_all_by_method_link("NOT_AN_EXISTING_METHOD_LINK");
  ok($method_link_species_sets);
  ok(scalar(@{$method_link_species_sets}), 0);


# 
# 11-12. Test fetch_all_by_method_link_type [1]
# 
debug("Test Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor::fetch_all_by_method_link_type [1]");
  $method_link_species_sets = $method_link_species_set_adaptor->fetch_all_by_method_link_type("BLASTZ_NET");
  ok(scalar(@{$method_link_species_sets}), 2);
  @$method_link_species_sets = sort {$a->dbID <=> $b->dbID } @$method_link_species_sets;
  $is_test_ok = 1;
  foreach my $this_method_link_species_set (@$method_link_species_sets) {
    $is_test_ok = 0 if (!$this_method_link_species_set->isa("Bio::EnsEMBL::Compara::MethodLinkSpeciesSet"));
    $is_test_ok = 0 if ($this_method_link_species_set->method_link_id != 1);
    $is_test_ok = 0 if ($this_method_link_species_set->method_link_type ne "BLASTZ_NET");
    $species = join(" - ", map {$_->name} @{$this_method_link_species_set->species_set});
    if ($this_method_link_species_set->dbID == 72) {
      $is_test_ok = 0 if ($species ne "Homo sapiens - Rattus norvegicus");
    } elsif ($this_method_link_species_set->dbID == 71) {
      $is_test_ok = 0 if ($species ne "Homo sapiens - Gallus gallus");
    } else {
      $is_test_ok = 0;
    }
  }
  ok($is_test_ok);


# 
# 13-14. Test fetch_all_by_method_link_type [2]
# 
debug("Test Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor::fetch_all_by_method_link_type [2]");
  $method_link_species_sets = $method_link_species_set_adaptor->fetch_all_by_method_link("NOT_AN_EXISTING_METHOD_LINK");
  ok($method_link_species_sets);
  ok(scalar(@{$method_link_species_sets}), 0);


# 
# 15-16. Test fetch_all_by_method_link_id [1]
# 
debug("Test Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor::fetch_all_by_method_link_id [1]");
  $method_link_species_sets = $method_link_species_set_adaptor->fetch_all_by_method_link(1);
  ok(scalar(@{$method_link_species_sets}), 2);
  @$method_link_species_sets = sort {$a->dbID <=> $b->dbID } @$method_link_species_sets;
  $is_test_ok = 1;
  foreach my $this_method_link_species_set (@$method_link_species_sets) {
    $is_test_ok = 0 if (!$this_method_link_species_set->isa("Bio::EnsEMBL::Compara::MethodLinkSpeciesSet"));
    $is_test_ok = 0 if ($this_method_link_species_set->method_link_id != 1);
    $is_test_ok = 0 if ($this_method_link_species_set->method_link_type ne "BLASTZ_NET");
    $species = join(" - ", map {$_->name} @{$this_method_link_species_set->species_set});
    if ($this_method_link_species_set->dbID == 72) {
      $is_test_ok = 0 if ($species ne "Homo sapiens - Rattus norvegicus");
    } elsif ($this_method_link_species_set->dbID == 71) {
      $is_test_ok = 0 if ($species ne "Homo sapiens - Gallus gallus");
    } else {
      $is_test_ok = 0;
    }
  }
  ok($is_test_ok);


# 
# 17-18. Test fetch_all_by_method_link_id [2]
# 
debug("Test Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor::fetch_all_by_method_link_id [2]");
  $method_link_species_sets = $method_link_species_set_adaptor->fetch_all_by_method_link(-1);
  ok($method_link_species_sets);
  ok(scalar(@{$method_link_species_sets}), 0);


# 
# 19-20. Test fetch_all_by_genome_db [1]
# 
debug("Test Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor::fetch_all_by_genome_db [1]");
  $method_link_species_sets = $method_link_species_set_adaptor->fetch_all_by_genome_db(3);
  ok(scalar(@{$method_link_species_sets}), 3);
  @$method_link_species_sets = sort {$a->dbID <=> $b->dbID } @$method_link_species_sets;
  $is_test_ok = 1;
  foreach my $this_method_link_species_set (@$method_link_species_sets) {
    $is_test_ok = 0 if (!$this_method_link_species_set->isa("Bio::EnsEMBL::Compara::MethodLinkSpeciesSet"));
    $species = join(" - ", map {$_->name} @{$this_method_link_species_set->species_set});
    if ($this_method_link_species_set->dbID == 72) {
      $is_test_ok = 0 if ($this_method_link_species_set->method_link_id != 1);
      $is_test_ok = 0 if ($this_method_link_species_set->method_link_type ne "BLASTZ_NET");
      $is_test_ok = 0 if ($species ne "Homo sapiens - Rattus norvegicus");
    } elsif ($this_method_link_species_set->dbID == 28) {
      $is_test_ok = 0 if ($this_method_link_species_set->method_link_id != 201);
      $is_test_ok = 0 if ($this_method_link_species_set->method_link_type ne "ENSEMBL_ORTHOLOGUES");
      $is_test_ok = 0 if ($species ne "Homo sapiens - Rattus norvegicus");
    } elsif ($this_method_link_species_set->dbID == 68) {
      $is_test_ok = 0 if ($this_method_link_species_set->method_link_id != 301);
      $is_test_ok = 0 if ($this_method_link_species_set->method_link_type ne "FAMILY");
      $is_test_ok = 0 if ($species !~ /^Homo sapiens - Mus musculus - Rattus norvegicus - Fugu rubripes/);
    } else {
      $is_test_ok = 0;
    }
  }
  ok($is_test_ok);


# 
# 21-22. Test fetch_all_by_genome_db [2]
# 
debug("Test Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor::fetch_all_by_genome_db [2]");
  $method_link_species_sets = $method_link_species_set_adaptor->fetch_all_by_genome_db(
          $genome_db_adaptor->fetch_by_dbID(3)
      );
  ok(scalar(@{$method_link_species_sets}), 3);
  @$method_link_species_sets = sort {$a->dbID <=> $b->dbID } @$method_link_species_sets;
  $is_test_ok = 1;
  foreach my $this_method_link_species_set (@$method_link_species_sets) {
    $is_test_ok = 0 if (!$this_method_link_species_set->isa("Bio::EnsEMBL::Compara::MethodLinkSpeciesSet"));
    $species = join(" - ", map {$_->name} @{$this_method_link_species_set->species_set});
    if ($this_method_link_species_set->dbID == 72) {
      $is_test_ok = 0 if ($this_method_link_species_set->method_link_id != 1);
      $is_test_ok = 0 if ($this_method_link_species_set->method_link_type ne "BLASTZ_NET");
      $is_test_ok = 0 if ($species ne "Homo sapiens - Rattus norvegicus");
    } elsif ($this_method_link_species_set->dbID == 28) {
      $is_test_ok = 0 if ($this_method_link_species_set->method_link_id != 201);
      $is_test_ok = 0 if ($this_method_link_species_set->method_link_type ne "ENSEMBL_ORTHOLOGUES");
      $is_test_ok = 0 if ($species ne "Homo sapiens - Rattus norvegicus");
    } elsif ($this_method_link_species_set->dbID == 68) {
      $is_test_ok = 0 if ($this_method_link_species_set->method_link_id != 301);
      $is_test_ok = 0 if ($this_method_link_species_set->method_link_type ne "FAMILY");
      $is_test_ok = 0 if ($species !~ /^Homo sapiens - Mus musculus - Rattus norvegicus - Fugu rubripes/);
    } else {
      $is_test_ok = 0;
    }
  }
  ok($is_test_ok);


# 
# 23. Test fetch_all_by_genome_db [3]
# 
debug("Test Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor::fetch_all_by_genome_db [3]");
  $method_link_species_sets = eval {
          $method_link_species_set_adaptor->fetch_all_by_genome_db("THIS IS A WRONG ARGUMENT");
      };
  ok($method_link_species_sets, undef, "Testing failure");


# 
# 24. Test fetch_all_by_genome_db [4]
# 
debug("Test Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor::fetch_all_by_genome_db [4]");
  $method_link_species_sets = $method_link_species_set_adaptor->fetch_all_by_genome_db(0);
  ok(scalar(@{$method_link_species_sets}), 0);
  @$method_link_species_sets = sort {$a->dbID <=> $b->dbID } @$method_link_species_sets;
  $is_test_ok = 1;
  foreach my $this_method_link_species_set (@$method_link_species_sets) {
    $is_test_ok = 0 if (!$this_method_link_species_set->isa("Bio::EnsEMBL::Compara::MethodLinkSpeciesSet"));
    $species = join(" - ", map {$_->name} @{$this_method_link_species_set->species_set});
    if ($this_method_link_species_set->dbID == 72) {
      $is_test_ok = 0 if ($this_method_link_species_set->method_link_id != 1);
      $is_test_ok = 0 if ($this_method_link_species_set->method_link_type ne "BLASTZ_NET");
      $is_test_ok = 0 if ($species ne "Homo sapiens - Rattus norvegicus");
    } elsif ($this_method_link_species_set->dbID == 28) {
      $is_test_ok = 0 if ($this_method_link_species_set->method_link_id != 201);
      $is_test_ok = 0 if ($this_method_link_species_set->method_link_type ne "ENSEMBL_ORTHOLOGUES");
      $is_test_ok = 0 if ($species ne "Homo sapiens - Rattus norvegicus");
    } elsif ($this_method_link_species_set->dbID == 68) {
      $is_test_ok = 0 if ($this_method_link_species_set->method_link_id != 301);
      $is_test_ok = 0 if ($this_method_link_species_set->method_link_type ne "FAMILY");
      $is_test_ok = 0 if ($species !~ /^Homo sapiens - Mus musculus - Rattus norvegicus - Fugu rubripes/);
    } else {
      $is_test_ok = 0;
    }
  }
  ok($is_test_ok);


# 
# 25-26. Test fetch_all_by_genome_db_id [1]
# 
debug("Test Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor::fetch_all_by_genome_db_id [1]");
  $method_link_species_sets = $method_link_species_set_adaptor->fetch_all_by_genome_db_id(3);
  ok(scalar(@{$method_link_species_sets}), 3);


# 
# 27-28. Test fetch_all_by_genome_db_id [2]
# 
debug("Test Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor::fetch_all_by_genome_db_id [2]");
  $method_link_species_sets = $method_link_species_set_adaptor->fetch_all_by_genome_db_id(-1);
  ok($method_link_species_sets);
  ok(scalar(@{$method_link_species_sets}), 0);

# 
# 29. Test fetch_all_by_genome_db_id [2]
# 
debug("Test Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor::fetch_all_by_method_link_and_genome_db [2]");
  $method_link_species_sets = $method_link_species_set_adaptor->fetch_all_by_method_link_and_genome_db(1, 1);
  ok(scalar(@{$method_link_species_sets}), 2);

# 
# 30. Test fetch_all_by_genome_db_id [2]
# 
debug("Test Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor::fetch_all_by_method_link_and_genome_db [2]");
  $method_link_species_sets = $method_link_species_set_adaptor->fetch_all_by_method_link_and_genome_db(
          "BLASTZ_NET",
          $genome_db_adaptor->fetch_by_dbID(1));
  ok(scalar(@{$method_link_species_sets}), 2);

# 
# 31. Test fetch_by_method_link_and_genome_db_ids
# 
debug("Test Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor::fetch_by_method_link_and_genome_db_ids [1]");
  $method_link_species_set = $method_link_species_set_adaptor->fetch_by_method_link_and_genome_db_ids(
          "BLASTZ_NET", [1, 3]
          );
  $is_test_ok = 1;
  $is_test_ok = 0 if (!$method_link_species_set->isa("Bio::EnsEMBL::Compara::MethodLinkSpeciesSet"));
  $is_test_ok = 0 if ($method_link_species_set->dbID != 72);
  $is_test_ok = 0 if ($method_link_species_set->method_link_id != 1);
  $is_test_ok = 0 if ($method_link_species_set->method_link_type ne "BLASTZ_NET");
  $species = join(" - ", map {$_->name} @{$method_link_species_set->species_set});
  $is_test_ok = 0 if ($species ne "Homo sapiens - Rattus norvegicus");
  ok($is_test_ok);


# 
# 32. Test fetch_by_method_link_and_genome_db_ids
# 
debug("Test Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor::fetch_by_method_link_and_genome_db_ids [2]");
  $method_link_species_set = $method_link_species_set_adaptor->fetch_by_method_link_and_genome_db_ids(
          1, [1, 3]
          );
  $is_test_ok = 1;
  $is_test_ok = 0 if (!$method_link_species_set->isa("Bio::EnsEMBL::Compara::MethodLinkSpeciesSet"));
  $is_test_ok = 0 if ($method_link_species_set->dbID != 72);
  $is_test_ok = 0 if ($method_link_species_set->method_link_id != 1);
  $is_test_ok = 0 if ($method_link_species_set->method_link_type ne "BLASTZ_NET");
  $species = join(" - ", map {$_->name} @{$method_link_species_set->species_set});
  $is_test_ok = 0 if ($species ne "Homo sapiens - Rattus norvegicus");
  ok($is_test_ok);


# 
# 33. Test fetch_by_method_link_and_genome_db_ids
# 
debug("Test Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor::fetch_by_method_link_and_genome_db_ids [3]");
  $method_link_species_set = $method_link_species_set_adaptor->fetch_by_method_link_and_genome_db_ids(-1, [1,2]);
  ok(!$method_link_species_set);


# 
# 34. Check new method
# 
debug( "Check Bio::EnsEMBL::Compara::MethodLinkSpeciesSet::new method [1]" );
  $method_link_species_set = new Bio::EnsEMBL::Compara::MethodLinkSpeciesSet(
        -dbID => 1,
        -adaptor => $method_link_species_set_adaptor,
        -method_link_id => 1,
        -method_link_type => "BLASTZ_NET",
        -species_set => [
            $genome_db_adaptor->fetch_by_name_assembly("Homo sapiens"),
            $genome_db_adaptor->fetch_by_name_assembly("Rattus norvegicus")],
    );
  $is_test_ok = 1;
  $is_test_ok = 0 if (!$method_link_species_set->isa("Bio::EnsEMBL::Compara::MethodLinkSpeciesSet"));
  $is_test_ok = 0 if ($method_link_species_set->dbID != 1);
  $is_test_ok = 0 if ($method_link_species_set->method_link_id != 1);
  $is_test_ok = 0 if ($method_link_species_set->method_link_type ne "BLASTZ_NET");
  $species = join(" - ", map {$_->name} @{$method_link_species_set->species_set});
  $is_test_ok = 0 if ($species ne "Homo sapiens - Rattus norvegicus");
  ok($is_test_ok);


# 
# 35-36. Check store method with already existing entry
# 
debug( "Check Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSet::store method [1]" );
  $method_link_species_set_adaptor->store($method_link_species_set);
  ok($method_link_species_set->dbID, 72);
  ok(scalar(@{$method_link_species_set_adaptor->fetch_all}), 5);


# 
# 37. Check new method(2)
# 
debug( "Check Bio::EnsEMBL::Compara::MethodLinkSpeciesSet::new method [2]" );
  $method_link_species_set = new Bio::EnsEMBL::Compara::MethodLinkSpeciesSet(
        -method_link_id => 1,
        -method_link_type => "BLASTZ_NET",
        -species_set => [
            $genome_db_adaptor->fetch_by_name_assembly("Gallus gallus"),
            $genome_db_adaptor->fetch_by_name_assembly("Mus musculus")],
    );
  $is_test_ok = 1;
  $is_test_ok = 0 if (!$method_link_species_set->isa("Bio::EnsEMBL::Compara::MethodLinkSpeciesSet"));
  $is_test_ok = 0 if ($method_link_species_set->method_link_id != 1);
  $is_test_ok = 0 if ($method_link_species_set->method_link_type ne "BLASTZ_NET");
  $species = join(" - ", map {$_->name} @{$method_link_species_set->species_set});
  $is_test_ok = 0 if ($species ne "Gallus gallus - Mus musculus");
  ok($is_test_ok);


# 
# 38. Check store method with a new entry
# 
debug( "Check Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSet::store method [2]" );
  $multi->save("compara", "method_link_species_set");
  $method_link_species_set_adaptor->store($method_link_species_set);
  ok(scalar(@{$method_link_species_set_adaptor->fetch_all}), 6);


# 
# 39. Check delete method
# 
debug( "Check Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSet::delete method" );
  $method_link_species_set_adaptor->delete($method_link_species_set->dbID);
  ok(scalar(@{$method_link_species_set_adaptor->fetch_all}), 5);
  $method_link_species_set_adaptor->store($method_link_species_set);
  ok(scalar(@{$method_link_species_set_adaptor->fetch_all}), 6);
  $multi->restore("compara", "method_link_species_set");
  ok(scalar(@{$method_link_species_set_adaptor->fetch_all}), 5);
