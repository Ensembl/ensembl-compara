use strict;
use warnings;

use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::Test::TestUtils qw(debug test_getter_setter);

BEGIN {
  $| = 1;
  use Test;
  plan tests => 14;
}

#set to 1 to turn on debug prints
our $verbose = 0;


my $multi = Bio::EnsEMBL::Test::MultiTestDB->new('multi');

my $homo_sapiens = Bio::EnsEMBL::Test::MultiTestDB->new("homo_sapiens");

my $hs_dba = $homo_sapiens->get_DBAdaptor('core');
my $compara_dba = $multi->get_DBAdaptor('compara');

my $human_name     = $hs_dba->get_MetaContainer->get_Species->binomial;
my $human_assembly = $hs_dba->get_CoordSystemAdaptor->fetch_all->[0]->version;

my $gdba = $compara_dba->get_GenomeDBAdaptor;

my $hs_gdb = $gdba->fetch_by_name_assembly($human_name,$human_assembly);
$hs_gdb->db_adaptor($hs_dba);

my $ma = $compara_dba->get_MemberAdaptor;
my $fa = $compara_dba->get_FamilyAdaptor;
my $mlssa = $compara_dba->get_MethodLinkSpeciesSetAdaptor;

my $source = "ENSEMBLGENE";
my ($family_id, $family_stable_id, $family_description, $family_method_link_species_set_id,
    $stable_id) = $compara_dba->dbc->db_handle->selectrow_array("
        SELECT family_id, family.stable_id, family.description,
          method_link_species_set_id, member.stable_id
        FROM family LEFT JOIN family_member USING (family_id)
          LEFT JOIN member USING (member_id) LEFT JOIN genome_db USING (genome_db_id)
        WHERE source_name = '$source' AND genome_db.name = 'Homo sapiens' LIMIT 1");

#######
#  1  #
#######

my $member = $ma->fetch_by_source_stable_id($source,$stable_id);

ok($member);

my $families = $fa->fetch_by_Member($member);

ok($families);
ok (scalar @{$families} == 1);
$verbose && debug("\nnb of families: ". scalar @{$families});

$families = $fa->fetch_all_by_Member_method_link_type($member,"FAMILY");

$families = $fa->fetch_by_Member_source_stable_id($source,$stable_id);

ok($families);
ok (scalar @{$families} == 1);
$verbose && debug("\nnb of families: ". scalar @{$families});

my $family = $families->[0];

ok( $family );
ok( $family->dbID, $family_id );
$verbose && debug($family->dbID);
ok( $family->stable_id, $family_stable_id );
$verbose && debug($family->stable_id);
ok( $family->description, $family_description );
$verbose && debug($family->description);
ok( $family->method_link_species_set_id, $family_method_link_species_set_id );
$verbose && debug($family->method_link_species_set_id);
ok( $family->method_link_type, "FAMILY" );
$verbose && debug($family->method_link_type);
ok( $family->adaptor =~ /^Bio::EnsEMBL::Compara::DBSQL::FamilyAdaptor/ );

$multi->hide('compara', 'family');
$multi->hide('compara', 'family_member');
$multi->hide('compara', 'method_link_species_set');

$family->{'_dbID'} = undef;
$family->{'_adaptor'} = undef;
$family->{'_method_link_species_set_id'} = undef;

$fa->store($family);

my $sth = $compara_dba->dbc->prepare('SELECT family_id
                                FROM family
                                WHERE family_id = ?');

$sth->execute($family->dbID);

ok($family->dbID && ($family->adaptor == $fa));
debug("family->dbID = " . $family->dbID);

my ($id) = $sth->fetchrow_array;
$sth->finish;

ok($id && $id == $family->dbID);
debug("[$id] == [" . $family->dbID . "]?");

$multi->restore('compara', 'family');
$multi->restore('compara', 'family_member');
$multi->restore('compara', 'method_link_species_set');
