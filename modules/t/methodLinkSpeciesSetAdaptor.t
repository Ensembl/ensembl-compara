#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::Exception;

use Bio::EnsEMBL::Utils::Exception qw (warning verbose);
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::Test::TestUtils;

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
my $blastz_net_method_link_id = 1;

my $all_mlss;
my ($human_genome_db_id) = $compara_db->dbc->db_handle->selectrow_array("
    SELECT genome_db_id
    FROM genome_db
    WHERE name = 'homo_sapiens'");

#human lastz entries
my ($num_human_lastz) = $compara_db->dbc->db_handle->selectrow_array("
    SELECT count(*)
    FROM method_link_species_set
    JOIN method_link USING (method_link_id)
    WHERE type = 'LASTZ_NET' AND name LIKE '%H.sap%'");

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
# Check premises
# 
debug( "Check premises" );
ok(defined($multi) and defined($homo_sapiens) and defined($mus_musculus) and defined($rattus_norvegicus)
    and defined($compara_db));


# 
# Check adaptor
# 
debug("Check Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor");
$method_link_species_set_adaptor = $compara_db->get_MethodLinkSpeciesSetAdaptor();
isa_ok($method_link_species_set_adaptor, "Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor");

# 
# Test fetch_all
# 
subtest "Test Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor::fetch_all", sub {
  $method_link_species_sets = $method_link_species_set_adaptor->fetch_all;
  is(scalar(@{$method_link_species_sets}), values(%$all_mlss));

  @$method_link_species_sets = sort {$a->dbID <=> $b->dbID } @$method_link_species_sets;
  $is_test_ok = 1;
  foreach my $this_method_link_species_set (@$method_link_species_sets) {
    isa_ok($this_method_link_species_set, "Bio::EnsEMBL::Compara::MethodLinkSpeciesSet");

    #species string ends up being too long
    #$species = join(",", sort map {$_->name} @{$this_method_link_species_set->species_set});

    my $gdbs = join(",", sort {$a <=> $b} map {$_->dbID} @{$this_method_link_species_set->species_set_obj->genome_dbs});
    if (defined($all_mlss->{$this_method_link_species_set->dbID})) {
        print $this_method_link_species_set->dbID . "\n";
      is($this_method_link_species_set->method->dbID, $all_mlss->{$this_method_link_species_set->dbID}->{method_link_id});
      is($this_method_link_species_set->method->type, $all_mlss->{$this_method_link_species_set->dbID}->{type});
      is($this_method_link_species_set->method->class, $all_mlss->{$this_method_link_species_set->dbID}->{class});
#      is($species, $all_mlss->{$this_method_link_species_set->dbID}->{species_set});
      is($gdbs, $all_mlss->{$this_method_link_species_set->dbID}->{gdbid_set});
    }
  }
  done_testing();
};


# 
# Test fetch_by_dbID
# 
subtest "Test Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor::fetch_by_dbID [1]", sub {
    my $this_method_link_species_set_id = [keys(%$all_mlss)]->[0];
    my $method_link_species_set = $method_link_species_set_adaptor->fetch_by_dbID($this_method_link_species_set_id);

    isa_ok($method_link_species_set, "Bio::EnsEMBL::Compara::MethodLinkSpeciesSet");
    is($method_link_species_set->dbID, $this_method_link_species_set_id);
    is($method_link_species_set->method->dbID, $all_mlss->{$this_method_link_species_set_id}->{method_link_id});
    is($method_link_species_set->method->type, $all_mlss->{$this_method_link_species_set_id}->{type});
    is($method_link_species_set->method->class, $all_mlss->{$this_method_link_species_set_id}->{class});

    my $species = join(",", sort map {$_->name} @{$method_link_species_set->species_set_obj->genome_dbs});
    is ($species, $all_mlss->{$this_method_link_species_set_id}->{species_set});

    done_testing();
};


# 
# Test fetch_by_dbID (invalid dbID)
# 
subtest "Test Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor::fetch_by_dbID [2]", sub {
    throws_ok {$method_link_species_set_adaptor->fetch_by_dbID(0)} qr/dbID must be defined and nonzero/, 'invalid dbID';

    my $method_link_species_set = $method_link_species_set_adaptor->fetch_by_dbID(-1);
    ok(!$method_link_species_set);

    done_testing();
};



# 
# Test fetch_all_by_method_type [1]
# 
subtest "Test Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor::fetch_all_by_method_link_type [1]", sub {
    my $this_type = [map {$_->{type}} values(%$all_mlss)]->[0];
    
    my $method_link_species_sets = $method_link_species_set_adaptor->fetch_all_by_method_link_type($this_type);
    is(scalar(@{$method_link_species_sets}), grep {$_->{type} eq $this_type} values(%$all_mlss));

    check_mlss($method_link_species_sets);

    done_testing();
};

# 
# Test fetch_all_by_method_link_type [2]
# 
subtest "Test Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor::fetch_all_by_method_link_type [2]", sub {
    my $method_link_species_sets = $method_link_species_set_adaptor->fetch_all_by_method_link_type("NOT_AN_EXISTING_METHOD_LINK");
    ok($method_link_species_sets);
    is(scalar(@{$method_link_species_sets}), 0);
    done_testing();
};

# 
# Test fetch_all_by_GenomeDB [1]
# 
my $species_name = [split(",", [map {$_->{species_set}} values(%$all_mlss)]->[0])]->[0];
subtest "Test Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor::fetch_all_by_GenomeDB [1]", sub {
    print "name $species_name\n";

    my $method_link_species_sets = $method_link_species_set_adaptor->fetch_all_by_GenomeDB(
                                                                                           $genome_db_adaptor->fetch_by_name_assembly($species_name)
                                                                                          );
    is(scalar(@{$method_link_species_sets}), grep {$_->{species_set} =~ /$species_name/} values(%$all_mlss));
    check_mlss($method_link_species_sets);

    done_testing();
};


# 
# Test fetch_all_by_GenomeDB [2]
# 
subtest "Test Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor::fetch_all_by_GenomeDB [2]", sub {

    throws_ok {$method_link_species_set_adaptor->fetch_all_by_GenomeDB("THIS IS A WRONG ARGUMENT")} qr/\[.+\] must be a Bio::EnsEMBL::Compara::GenomeDB object/, 'invalid GenomeDB';

    my $method_link_species_sets = eval {
        $method_link_species_set_adaptor->fetch_all_by_GenomeDB("THIS IS A WRONG ARGUMENT");
    };
    is($method_link_species_sets, undef, "Testing failure");

    done_testing();
};

# 
# Test fetch_all_by_method_link_type_GenomeDB
# 
subtest "Test Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor::fetch_all_by_method_link_type_GenomeDB [2]", sub {
  my $method_link_species_sets = $method_link_species_set_adaptor->fetch_all_by_method_link_type_GenomeDB(
                                                                                                       "LASTZ_NET",
                                                                                                       $genome_db_adaptor->fetch_by_dbID($human_genome_db_id)
      );
  is(scalar(@{$method_link_species_sets}), $num_human_lastz);
  done_testing();
};


# 
# Test fetch_by_method_link_type_GenomeDBs
# 
subtest "Test Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor::fetch_by_method_link_type_GenomeDBs", sub {
    my $this_method_link_species_set_id = [keys(%$all_mlss)]->[0];
    my $method_link_species_set = $method_link_species_set_adaptor->fetch_by_method_link_type_GenomeDBs(
                                                                                                        $all_mlss->{$this_method_link_species_set_id}->{type},
                                                                                                      [map {$genome_db_adaptor->fetch_by_dbID($_)} split(",", $all_mlss->{$this_method_link_species_set_id}->{gdbid_set})]
                                                                                                       );
    my $method_link_species_sets;
    push @$method_link_species_sets, $method_link_species_set;
    check_mlss($method_link_species_sets);

  done_testing();
};


# 
# Test fetch_by_method_link_type_genome_db_ids
# 
subtest "Test Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor::fetch_by_method_link_type_genome_db_ids", sub {
    my $this_method_link_species_set_id = [keys(%$all_mlss)]->[0];

    my $method_link_species_set = $method_link_species_set_adaptor->fetch_by_method_link_type_genome_db_ids(
                                                                                                            $all_mlss->{$this_method_link_species_set_id}->{type},
          [map {$genome_db_adaptor->fetch_by_dbID($_)->dbID} split(",",
                                                                   $all_mlss->{$this_method_link_species_set_id}->{gdbid_set})]
      );
    
    my $method_link_species_sets;
    push @$method_link_species_sets, $method_link_species_set;
    check_mlss($method_link_species_sets);
    done_testing();
};



# 
# Check new method
# 
subtest "Check Bio::EnsEMBL::Compara::MethodLinkSpeciesSet::new method", sub {
    my $this_method_link_species_set_id = [keys(%$all_mlss)]->[0];

    my $method = Bio::EnsEMBL::Compara::Method->new(-dbID => $all_mlss->{$this_method_link_species_set_id}->{method_link_id}, 
                                                    -type => $all_mlss->{$this_method_link_species_set_id}->{type},
                                                    -class => $all_mlss->{$this_method_link_species_set_id}->{class});

    my $species_set_obj = Bio::EnsEMBL::Compara::SpeciesSet->new(
                                                  -genome_dbs => [map {$genome_db_adaptor->fetch_by_dbID($_)} split(",",
                                                                  $all_mlss->{$this_method_link_species_set_id}->{gdbid_set})]
                                                                );
    
    my $method_link_species_set = Bio::EnsEMBL::Compara::MethodLinkSpeciesSet->new(
                                                                -dbID => $this_method_link_species_set_id,
                                                                -adaptor => $method_link_species_set_adaptor,
                                                                -method             => $method,
                                                                -species_set_obj    => $species_set_obj,
                                                               );
    my $method_link_species_sets;
    push @$method_link_species_sets, $method_link_species_set;
    check_mlss($method_link_species_sets);

    done_testing();
};

# 
# Check store method with already existing entry
# 
subtest "Check Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSet::store method [1]", sub {
    my $this_method_link_species_set_id = [keys(%$all_mlss)]->[0];

    my $method = Bio::EnsEMBL::Compara::Method->new(-dbID => $all_mlss->{$this_method_link_species_set_id}->{method_link_id}, 
                                                    -type => $all_mlss->{$this_method_link_species_set_id}->{type},
                                                    -class => $all_mlss->{$this_method_link_species_set_id}->{class});

    my $species_set_obj = Bio::EnsEMBL::Compara::SpeciesSet->new(
                                                  -genome_dbs => [map {$genome_db_adaptor->fetch_by_dbID($_)} split(",",
                                                                  $all_mlss->{$this_method_link_species_set_id}->{gdbid_set})]
                                                                );
    
    my $method_link_species_set = Bio::EnsEMBL::Compara::MethodLinkSpeciesSet->new(
                                                                -dbID => $this_method_link_species_set_id,
                                                                -adaptor => $method_link_species_set_adaptor,
                                                                -method             => $method,
                                                                -species_set_obj    => $species_set_obj);

    $method_link_species_set_adaptor->store($method_link_species_set);
    is($method_link_species_set->dbID, $this_method_link_species_set_id);
    is(scalar(@{$method_link_species_set_adaptor->fetch_all}), values(%$all_mlss));


    done_testing();
};


# 
# Check store method with a new entry
# 
subtest "Check Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSet::store method [2]", sub {

    my $method = Bio::EnsEMBL::Compara::Method->new(-dbID => $blastz_net_method_link_id,
                                                    -type => "BLASTZ_NET",
                                                    -class => "GenomicAlignBlock.pairwise_alignment");

    my $species_set_obj = Bio::EnsEMBL::Compara::SpeciesSet->new(
                                                  -genome_dbs => [ $genome_db_adaptor->fetch_by_name_assembly("felis_catus"),
                                                                 $genome_db_adaptor->fetch_by_name_assembly("mus_musculus")],                                                               );
    
    my $method_link_species_set = Bio::EnsEMBL::Compara::MethodLinkSpeciesSet->new(
                                                                                   -method             => $method,
                                                                                   -species_set_obj    => $species_set_obj,
                                                                                   -max_alignment_length => 1000);

    $multi->hide("compara", "method_link_species_set", "method_link", "species_set", "method_link_species_set_tag");
    $method_link_species_set_adaptor->store($method_link_species_set);
    is(scalar(@{$method_link_species_set_adaptor->fetch_all}), 1);
    is(scalar(@{$method_link_species_set->get_all_values_for_tag("max_align")}), 1);

    $multi->restore("compara", "method_link_species_set", "method_link", "species_set", "method_link_species_set_tag");

    done_testing();
};


# 
# Check delete method
# 
subtest "Check Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSet::delete method", sub {

    my $method = Bio::EnsEMBL::Compara::Method->new(-dbID => $blastz_net_method_link_id,
                                                    -type => "BLASTZ_NET",
                                                    -class => "GenomicAlignBlock.pairwise_alignment");

    my $species_set_obj = Bio::EnsEMBL::Compara::SpeciesSet->new(
                                                  -genome_dbs => [ $genome_db_adaptor->fetch_by_name_assembly("felis_catus"),
                                                                 $genome_db_adaptor->fetch_by_name_assembly("mus_musculus")],                                                               );
    
    my $method_link_species_set = Bio::EnsEMBL::Compara::MethodLinkSpeciesSet->new(
                                                                                   -method             => $method,
                                                                                   -species_set_obj    => $species_set_obj,
                                                                                   -max_alignment_length => 1000);

    $multi->hide("compara", "method_link_species_set", "method_link", "species_set", "method_link_species_set_tag");

    $method_link_species_set_adaptor->store($method_link_species_set);
    is(scalar(@{$method_link_species_set_adaptor->fetch_all}), 1);
    is(scalar(@{$method_link_species_set->get_all_values_for_tag("max_align")}), 1);

    $method_link_species_set_adaptor->delete($method_link_species_set->dbID);
    is(scalar(@{$method_link_species_set_adaptor->fetch_all}), 0);

    #HACK - comment out for now - problem with caching?
    #is(scalar(@{$method_link_species_set->get_all_values_for_tag("max_align")}), 0);

    $multi->restore("compara", "method_link_species_set", "method_link", "species_set", "method_link_species_set_tag");

    #HACK - comment out for now - problem with caching?
    #is(scalar(@{$method_link_species_set_adaptor->fetch_all}), values(%$all_mlss));

    done_testing();
};


sub check_mlss {
    my ($method_link_species_sets) = @_;

    @$method_link_species_sets = sort {$a->dbID <=> $b->dbID } @$method_link_species_sets;

    foreach my $this_method_link_species_set (@$method_link_species_sets) {
        isa_ok($this_method_link_species_set, "Bio::EnsEMBL::Compara::MethodLinkSpeciesSet");

        #my $species = join(",", sort map {$_->name} @{$this_method_link_species_set->species_set_obj->genome_dbs});
        my $gdbs = join(",", sort {$a <=> $b} map {$_->dbID} @{$this_method_link_species_set->species_set_obj->genome_dbs});

        if (defined($all_mlss->{$this_method_link_species_set->dbID})) {
            is($this_method_link_species_set->method->dbID, $all_mlss->{$this_method_link_species_set->dbID}->{method_link_id},
'dbID');
            is($this_method_link_species_set->method->type, $all_mlss->{$this_method_link_species_set->dbID}->{type}, 'type');
            is($this_method_link_species_set->method->class, $all_mlss->{$this_method_link_species_set->dbID}->{class}, 'class');
            #is($species, $all_mlss->{$this_method_link_species_set->dbID}->{species_set});
            is($gdbs, $all_mlss->{$this_method_link_species_set->dbID}->{gdbid_set}, 'gdbid_set');
        } else {
            ok(0);
        }
    }
}

done_testing();
