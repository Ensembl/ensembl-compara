#!/usr/local/ensembl/bin/perl -w

#
# Test script for Bio::EnsEMBL::Compara::MethodLinkSpeciesSet module
#
# Written by Javier Herrero (jherrero@ebi.ac.uk)
#
# Copyright (c) 2004. EnsEMBL Team
#
# You may distribute this module under the same terms as perl itself

=head1 NAME

methodLinkSpeciesSet.t

=head1 SYNOPSIS

For running this test only:
perl -w ../../../ensembl-test/scripts/runtests.pl methodLinkSpeciesSet.t

For running all the test scripts:
perl -w ../../../ensembl-test/scripts/runtests.pl

=head1 DESCRIPTION

This script uses a small compara database build following the specifitions given in the MultiTestDB.conf file.

This script (as far as possible) tests all the methods defined in the
Bio::EnsEMBL::Compara::MethodLinkSpeciesSet module.

This script includes 5 tests.

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
	plan tests => 5;
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
# 3. Test new method
# 
debug( "Test Bio::EnsEMBL::Compara::MethodLinkSpeciesSet::new method" );
  $method_link_species_set = new Bio::EnsEMBL::Compara::MethodLinkSpeciesSet(
        -dbID => 1,
#         -adaptor => $method_link_species_set_adaptor,
        -method_link_id => 1,
        -method_link_type => "BLASTZ_NET",
        -method_link_class => "GenomicAlignBlock.pairwise_alignment",
        -species_set => [
            $genome_db_adaptor->fetch_by_name_assembly("Homo sapiens"),
            $genome_db_adaptor->fetch_by_name_assembly("Rattus norvegicus")],
    );
  $is_test_ok = 1;
  $is_test_ok = 2 if (!$method_link_species_set->isa("Bio::EnsEMBL::Compara::MethodLinkSpeciesSet"));
  $is_test_ok = 3 if ($method_link_species_set->dbID != 1);
  $is_test_ok = 4 if ($method_link_species_set->method_link_id != 1);
  $is_test_ok = 5 if ($method_link_species_set->method_link_type ne "BLASTZ_NET");
  $is_test_ok = 6 if ($method_link_species_set->method_link_class ne "GenomicAlignBlock.pairwise_alignment");
  $species = join(" - ", map {$_->name} @{$method_link_species_set->species_set});
  $is_test_ok = 7 if ($species ne "Homo sapiens - Rattus norvegicus");
  ok($is_test_ok);


# 
# 4. Test method_link_id method
# 
debug( "Test Bio::EnsEMBL::Compara::MethodLinkSpeciesSet::method_link_id method" );
  $method_link_species_set = new Bio::EnsEMBL::Compara::MethodLinkSpeciesSet(
        -dbID => 1,
        -adaptor => $method_link_species_set_adaptor,
#         -method_link_id => 1,
        -method_link_type => "BLASTZ_NET",
        -species_set => [
            $genome_db_adaptor->fetch_by_name_assembly("Homo sapiens"),
            $genome_db_adaptor->fetch_by_name_assembly("Rattus norvegicus")],
    );
  ok($method_link_species_set->method_link_id, 1);


# 
# 5. Test method_link_type method
# 
debug( "Test Bio::EnsEMBL::Compara::MethodLinkSpeciesSet::method_link_type method" );
  $method_link_species_set = new Bio::EnsEMBL::Compara::MethodLinkSpeciesSet(
        -dbID => 1,
        -adaptor => $method_link_species_set_adaptor,
        -method_link_id => 1,
#         -method_link_type => "BLASTZ_NET",
        -species_set => [
            $genome_db_adaptor->fetch_by_name_assembly("Homo sapiens"),
            $genome_db_adaptor->fetch_by_name_assembly("Rattus norvegicus")],
    );
  ok($method_link_species_set->method_link_type, "BLASTZ_NET");


1;
