use strict;
use warnings;

use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::Test::TestUtils qw(debug test_getter_setter);

BEGIN {
  $| = 1;
  use Test;
  plan tests => 11;
}

#set to 1 to turn on debug prints
our $verbose = 1;


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
my $ha = $compara_dba->get_HomologyAdaptor;
my $mlssa = $compara_dba->get_MethodLinkSpeciesSetAdaptor;

#######
#  1  #
#######

my $member = $ma->fetch_by_source_stable_id("ENSEMBLGENE","ENSG00000139926");

ok($member);

my $homologies = $ha->fetch_by_Member($member);

ok($homologies);

$homologies = $ha->fetch_all_by_Member_method_link_type($member,"ENSEMBL_ORTHOLOGUES");

#print STDERR "nb of homology: ", scalar @{$homology},"\n";

my $homology = $ha->fetch_by_Member_paired_species($member,"Rattus norvegicus")->[0];

ok( $homology );
ok( $homology->dbID == 323915 );
ok( $homology->stable_id eq "9606_10116_01092704852" );
ok( $homology->description eq "UBRH" );
ok( $homology->method_link_species_set_id == 28 );
ok( $homology->method_link_type eq "ENSEMBL_ORTHOLOGUES" );
ok( $homology->adaptor =~ /^Bio::EnsEMBL::Compara::DBSQL::HomologyAdaptor/ );

$multi->hide('compara', 'homology');
$multi->hide('compara', 'homology_member');
$multi->hide('compara', 'method_link_species_set');

$homology->{'_dbID'} = undef;
$homology->{'_adaptor'} = undef;
$homology->{'_method_link_species_set_id'} = undef;

$ha->store($homology);

my $sth = $compara_dba->dbc->prepare('SELECT homology_id
                                FROM homology
                                WHERE homology_id = ?');

$sth->execute($homology->dbID);

ok($homology->dbID && ($homology->adaptor == $ha));
debug("homology->dbID = " . $homology->dbID);

my ($id) = $sth->fetchrow_array;
$sth->finish;

ok($id && $id == $homology->dbID);
debug("[$id] == [" . $homology->dbID . "]?");

$multi->restore('compara', 'homology');
$multi->restore('compara', 'homology_member');
$multi->restore('compara', 'method_link_species_set');
