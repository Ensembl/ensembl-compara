use strict;
use warnings;

BEGIN { $| = 1;  
	use Test;
	plan tests => 31;
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
  ok(scalar(@{$method_link_species_sets}), 4);
  @$method_link_species_sets = sort {$a->dbID <=> $b->dbID } @$method_link_species_sets;
  $is_test_ok = 1;
  foreach my $this_method_link_species_set (@$method_link_species_sets) {
    $is_test_ok = 0 if (!$this_method_link_species_set->isa("Bio::EnsEMBL::Compara::MethodLinkSpeciesSet"));
    $is_test_ok = 0 if ($this_method_link_species_set->method_link_id != 1);
    $is_test_ok = 0 if ($this_method_link_species_set->method_link_type ne "BLASTZ_NET");
    $species = join(" - ", map {$_->name} @{$this_method_link_species_set->species_set});
    if ($this_method_link_species_set->dbID == 1) {
      $is_test_ok = 0 if ($species ne "Homo sapiens - Rattus norvegicus");
    } elsif ($this_method_link_species_set->dbID == 2) {
      $is_test_ok = 0 if ($species ne "Homo sapiens - Mus musculus");
    } elsif ($this_method_link_species_set->dbID == 3) {
      $is_test_ok = 0 if ($species ne "Mus musculus - Rattus norvegicus");
    } elsif ($this_method_link_species_set->dbID == 4) {
      $is_test_ok = 0 if ($species ne "Homo sapiens - Gallus gallus");
    } else {
      $is_test_ok = 0;
    }
  }
  ok($is_test_ok);


# 
# 5. Test fetch_by_dbID
# 
debug("Test Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor::fetch_by_dbID [1]");
  $method_link_species_set = $method_link_species_set_adaptor->fetch_by_dbID(1);
  $is_test_ok = 1;
  $is_test_ok = 0 if (!$method_link_species_set->isa("Bio::EnsEMBL::Compara::MethodLinkSpeciesSet"));
  $is_test_ok = 0 if ($method_link_species_set->dbID != 1);
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
  ok(scalar(@{$method_link_species_sets}), 4);
  @$method_link_species_sets = sort {$a->dbID <=> $b->dbID } @$method_link_species_sets;
  $is_test_ok = 1;
  foreach my $this_method_link_species_set (@$method_link_species_sets) {
    $is_test_ok = 0 if (!$this_method_link_species_set->isa("Bio::EnsEMBL::Compara::MethodLinkSpeciesSet"));
    $is_test_ok = 0 if ($this_method_link_species_set->method_link_id != 1);
    $is_test_ok = 0 if ($this_method_link_species_set->method_link_type ne "BLASTZ_NET");
    $species = join(" - ", map {$_->name} @{$this_method_link_species_set->species_set});
    if ($this_method_link_species_set->dbID == 1) {
      $is_test_ok = 0 if ($species ne "Homo sapiens - Rattus norvegicus");
    } elsif ($this_method_link_species_set->dbID == 2) {
      $is_test_ok = 0 if ($species ne "Homo sapiens - Mus musculus");
    } elsif ($this_method_link_species_set->dbID == 3) {
      $is_test_ok = 0 if ($species ne "Mus musculus - Rattus norvegicus");
    } elsif ($this_method_link_species_set->dbID == 4) {
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
  ok(scalar(@{$method_link_species_sets}), 4);
  @$method_link_species_sets = sort {$a->dbID <=> $b->dbID } @$method_link_species_sets;
  $is_test_ok = 1;
  foreach my $this_method_link_species_set (@$method_link_species_sets) {
    $is_test_ok = 0 if (!$this_method_link_species_set->isa("Bio::EnsEMBL::Compara::MethodLinkSpeciesSet"));
    $is_test_ok = 0 if ($this_method_link_species_set->method_link_id != 1);
    $is_test_ok = 0 if ($this_method_link_species_set->method_link_type ne "BLASTZ_NET");
    $species = join(" - ", map {$_->name} @{$this_method_link_species_set->species_set});
    if ($this_method_link_species_set->dbID == 1) {
      $is_test_ok = 0 if ($species ne "Homo sapiens - Rattus norvegicus");
    } elsif ($this_method_link_species_set->dbID == 2) {
      $is_test_ok = 0 if ($species ne "Homo sapiens - Mus musculus");
    } elsif ($this_method_link_species_set->dbID == 3) {
      $is_test_ok = 0 if ($species ne "Mus musculus - Rattus norvegicus");
    } elsif ($this_method_link_species_set->dbID == 4) {
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
  ok(scalar(@{$method_link_species_sets}), 4);
  @$method_link_species_sets = sort {$a->dbID <=> $b->dbID } @$method_link_species_sets;
  $is_test_ok = 1;
  foreach my $this_method_link_species_set (@$method_link_species_sets) {
    $is_test_ok = 0 if (!$this_method_link_species_set->isa("Bio::EnsEMBL::Compara::MethodLinkSpeciesSet"));
    $is_test_ok = 0 if ($this_method_link_species_set->method_link_id != 1);
    $is_test_ok = 0 if ($this_method_link_species_set->method_link_type ne "BLASTZ_NET");
    $species = join(" - ", map {$_->name} @{$this_method_link_species_set->species_set});
    if ($this_method_link_species_set->dbID == 1) {
      $is_test_ok = 0 if ($species ne "Homo sapiens - Rattus norvegicus");
    } elsif ($this_method_link_species_set->dbID == 2) {
      $is_test_ok = 0 if ($species ne "Homo sapiens - Mus musculus");
    } elsif ($this_method_link_species_set->dbID == 3) {
      $is_test_ok = 0 if ($species ne "Mus musculus - Rattus norvegicus");
    } elsif ($this_method_link_species_set->dbID == 4) {
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
# 19-20. Test fetch_all_by_genome_db_id [2]
# 
debug("Test Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor::fetch_all_by_genome_db_id [1]");
  $method_link_species_sets = $method_link_species_set_adaptor->fetch_all_by_genome_db_id(1);
  ok(scalar(@{$method_link_species_sets}), 3);
  @$method_link_species_sets = sort {$a->dbID <=> $b->dbID } @$method_link_species_sets;
  $is_test_ok = 1;
  foreach my $this_method_link_species_set (@$method_link_species_sets) {
    $is_test_ok = 0 if (!$this_method_link_species_set->isa("Bio::EnsEMBL::Compara::MethodLinkSpeciesSet"));
    $is_test_ok = 0 if ($this_method_link_species_set->method_link_id != 1);
    $is_test_ok = 0 if ($this_method_link_species_set->method_link_type ne "BLASTZ_NET");
    $species = join(" - ", map {$_->name} @{$this_method_link_species_set->species_set});
    if ($this_method_link_species_set->dbID == 1) {
      $is_test_ok = 0 if ($species ne "Homo sapiens - Rattus norvegicus");
    } elsif ($this_method_link_species_set->dbID == 2) {
      $is_test_ok = 0 if ($species ne "Homo sapiens - Mus musculus");
    } elsif ($this_method_link_species_set->dbID == 4) {
      $is_test_ok = 0 if ($species ne "Homo sapiens - Gallus gallus");
    } else {
      $is_test_ok = 0;
    }
  }
  ok($is_test_ok);


# 
# 21-22. Test fetch_all_by_genome_db_id [2]
# 
debug("Test Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor::fetch_all_by_genome_db_id [2]");
  $method_link_species_sets = $method_link_species_set_adaptor->fetch_all_by_genome_db_id(-1);
  ok($method_link_species_sets);
  ok(scalar(@{$method_link_species_sets}), 0);


# 
# 23. Test fetch_by_method_link_and_genome_db_ids
# 
debug("Test Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor::fetch_by_method_link_and_genome_db_ids [1]");
  $method_link_species_set = $method_link_species_set_adaptor->fetch_by_method_link_and_genome_db_ids(
          "BLASTZ_NET", [1, 3]
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
# 24. Test fetch_by_method_link_and_genome_db_ids
# 
debug("Test Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor::fetch_by_method_link_and_genome_db_ids [2]");
  $method_link_species_set = $method_link_species_set_adaptor->fetch_by_method_link_and_genome_db_ids(
          1, [1, 3]
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
# 25. Test fetch_by_method_link_and_genome_db_ids
# 
debug("Test Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor::fetch_by_method_link_and_genome_db_ids [3]");
  $method_link_species_set = $method_link_species_set_adaptor->fetch_by_method_link_and_genome_db_ids(-1, [1,2]);
  ok(!$method_link_species_set);


# 
# 26. Check new method
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
# 27-28. Check store method with already existing entry
# 
debug( "Check Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSet::store method [1]" );
  $method_link_species_set_adaptor->store($method_link_species_set);
  ok($method_link_species_set->dbID, 1);
  ok(scalar(@{$method_link_species_set_adaptor->fetch_all}), 4);


# 
# 29. Check new method(2)
# 
debug( "Check Bio::EnsEMBL::Compara::MethodLinkSpeciesSet::new method [2]" );
  $method_link_species_set = new Bio::EnsEMBL::Compara::MethodLinkSpeciesSet(
        -method_link_id => 1,
        -method_link_type => "BLASTZ_NET",
        -species_set => [
            $genome_db_adaptor->fetch_by_name_assembly("Gallus gallus"),
            $genome_db_adaptor->fetch_by_name_assembly("Rattus norvegicus")],
    );
  $is_test_ok = 1;
  $is_test_ok = 0 if (!$method_link_species_set->isa("Bio::EnsEMBL::Compara::MethodLinkSpeciesSet"));
  $is_test_ok = 0 if ($method_link_species_set->method_link_id != 1);
  $is_test_ok = 0 if ($method_link_species_set->method_link_type ne "BLASTZ_NET");
  $species = join(" - ", map {$_->name} @{$method_link_species_set->species_set});
  $is_test_ok = 0 if ($species ne "Gallus gallus - Rattus norvegicus");
  ok($is_test_ok);


# 
# 30. Check store method with a new entry
# 
debug( "Check Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSet::store method [2]" );
  $method_link_species_set_adaptor->store($method_link_species_set);
  ok(scalar(@{$method_link_species_set_adaptor->fetch_all}), 5);


# 
# 31. Check delete method
# 
debug( "Check Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSet::delete method" );
  $method_link_species_set_adaptor->delete($method_link_species_set->dbID);
  ok(scalar(@{$method_link_species_set_adaptor->fetch_all}), 4);

