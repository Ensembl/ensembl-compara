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

my $member = $ma->fetch_by_source_stable_id("ENSEMBLGENE","ENSG00000139926");

ok($member);
ok( $member->dbID ==  251282);
ok( $member->stable_id eq "ENSG00000139926" );
ok( $member->version == 6 );
ok( $member->description eq "NULL" );
ok( $member->source_name eq "ENSEMBLGENE" );
ok( $member->adaptor =~ /^Bio::EnsEMBL::Compara::DBSQL::MemberAdaptor/ );
ok( $member->chr_name eq "14" );
ok( $member->chr_start == 50108666 );
ok( $member->chr_end == 50187480 );
ok( $member->chr_strand == 1 );
ok( $member->taxon_id == 9606 );
ok( $member->genome_db_id == 1 );
ok( ! $member->sequence_id );

$member = $ma->fetch_by_source_stable_id("ENSEMBLPEP","ENSP00000343934");

ok($member);
ok( $member->dbID ==  251377);
ok( $member->stable_id eq "ENSP00000343934" );
ok( $member->version == 1 );
ok( $member->description eq "Transcript:ENST00000349825 Gene:ENSG00000139926 Chr:14 Start:50108666 End:50187480");
ok( $member->source_name eq "ENSEMBLPEP" );
ok( $member->adaptor =~ /^Bio::EnsEMBL::Compara::DBSQL::MemberAdaptor/ );
ok( $member->chr_name eq "14" );
ok( $member->chr_start == 50146593 );
ok( $member->chr_end == 50184785 );
ok( $member->chr_strand == 1 );
ok( $member->taxon_id == 9606 );
ok( $member->genome_db_id == 1 );
ok( $member->sequence_id == 143871 );

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
