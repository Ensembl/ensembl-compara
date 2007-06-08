use strict;
use warnings;

use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::Test::TestUtils qw(debug test_getter_setter);

BEGIN {
  $| = 1;
  use Test;
  plan tests => 30;
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


#######
#  1  #
#######

my ($member_id, $stable_id, $version, $source_name, $taxon_id, $genome_db_id, $sequence_id,
    $gene_member_id, $description, $chr_name, $chr_start, $chr_end, $chr_strand) =
        $compara_dba->dbc->db_handle->selectrow_array("SELECT * FROM member WHERE source_name = 'ENSEMBLGENE' LIMIT 1");

my $member = $ma->fetch_by_source_stable_id("ENSEMBLGENE", $stable_id);

ok($member);
ok( $member->dbID,  $member_id);
ok( $member->stable_id, $stable_id );
ok( $member->version, $version );
ok( $member->description, $description );
ok( $member->source_name, $source_name );
ok( $member->adaptor->isa("Bio::EnsEMBL::Compara::DBSQL::MemberAdaptor") );
ok( $member->chr_name, $chr_name );
ok( $member->chr_start, $chr_start );
ok( $member->chr_end, $chr_end );
ok( $member->chr_strand, $chr_strand );
ok( $member->taxon_id, $taxon_id );
ok( $member->genome_db_id, $genome_db_id );
ok( ! $member->sequence_id );

($member_id, $stable_id, $version, $source_name, $taxon_id, $genome_db_id, $sequence_id,
    $gene_member_id, $description, $chr_name, $chr_start, $chr_end, $chr_strand) =
        $compara_dba->dbc->db_handle->selectrow_array("SELECT * FROM member WHERE source_name = 'ENSEMBLPEP' LIMIT 1");

$member = $ma->fetch_by_source_stable_id("ENSEMBLPEP", $stable_id);

ok($member);
ok( $member->dbID,  $member_id);
ok( $member->stable_id, $stable_id );
ok( $member->version, $version );
ok( $member->description, $description );
ok( $member->source_name, $source_name );
ok( $member->adaptor->isa("Bio::EnsEMBL::Compara::DBSQL::MemberAdaptor") );
ok( $member->chr_name, $chr_name );
ok( $member->chr_start, $chr_start );
ok( $member->chr_end, $chr_end );
ok( $member->chr_strand, $chr_strand );
ok( $member->taxon_id, $taxon_id );
ok( $member->genome_db_id, $genome_db_id );
ok( $member->sequence_id );


$multi->hide('compara', 'member');
$member->{'_dbID'} = undef;
$member->{'_adaptor'} = undef;

$ma->store($member);

my $sth = $compara_dba->dbc->prepare('SELECT member_id
                                FROM member
                                WHERE member_id = ?');

$sth->execute($member->dbID);

ok($member->dbID && ($member->adaptor == $ma));
debug("member->dbID = " . $member->dbID);

my ($id) = $sth->fetchrow_array;
$sth->finish;

ok($id && $id == $member->dbID);
debug("[$id] == [" . $member->dbID . "]?");

$multi->restore('compara', 'member');
