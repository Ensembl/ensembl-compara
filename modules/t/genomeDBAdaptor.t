use strict;
use warnings;

use lib 't';
use MultiTestDB;
use TestUtils;

BEGIN {
  $| = 1;
  use Test;
  plan tests => 11;
}

our $verbose = 0;

my $multi = MultiTestDB->new('multi');

my $homo_sapiens = MultiTestDB->new("homo_sapiens");
my $mus_musculus = MultiTestDB->new("mus_musculus");
my $rattus_norvegicus = MultiTestDB->new("rattus_norvegicus");

my $hs_dba = $homo_sapiens->get_DBAdaptor('core');
my $mm_dba = $mus_musculus->get_DBAdaptor('core');
my $rn_dba = $rattus_norvegicus->get_DBAdaptor('core');
my $compara_dba = $multi->get_DBAdaptor('compara');

$compara_dba->add_db_adaptor($hs_dba);
$compara_dba->add_db_adaptor($mm_dba);
$compara_dba->add_db_adaptor($rn_dba);

my $mouse_name     = $mm_dba->get_MetaContainer->get_Species->binomial;
my $mouse_assembly = $mm_dba->get_CoordSystemAdaptor->fetch_top_level;
my $human_name     = $hs_dba->get_MetaContainer->get_Species->binomial;
my $human_assembly = $hs_dba->get_CoordSystemAdaptor->fetch_top_level;
my $rat_name       = $rn_dba->get_MetaContainer->get_Species->binomial;
my $rat_assembly   = $rn_dba->get_CoordSystemAdaptor->fetch_top_level;


#######
#  1  #
#######
my $gdba = $compara_dba->get_GenomeDBAdaptor;
ok($gdba);

#######
# 2-5 #
#######
my $gdb = $gdba->fetch_by_dbID(1);
ok($gdb->name eq 'Homo sapiens');
debug("gdb_name = " . $gdb->name);

ok($gdb->assembly eq 'NCBI34');
debug("gdb->assembly = " . $gdb->assembly);

ok($gdb->dbID eq 1);
debug("gdb->dbID = " . $gdb->dbID);

ok($gdb->taxon_id eq 9606);
debug("gdb->taxon_id = " . $gdb->taxon_id);

#######
# 6-9 #
#######
$gdb = $gdba->fetch_by_name_assembly('Mus musculus', 'NCBIM32');
ok($gdb->name eq 'Mus musculus');
debug("gdb_name = " . $gdb->name);

ok($gdb->assembly eq 'NCBIM32');
debug("gdb->assembly = " . $gdb->assembly);

ok($gdb->dbID == 2);
debug("gdb->dbID = " . $gdb->dbID);

ok($gdb->taxon_id == 10090);
debug("gdb->taxon_id = " . $gdb->taxon_id);

#########
# 10-11 #
#########
$multi->hide('compara', 'genome_db');
$gdb->{'dbID'} = undef;
$gdb->{'adaptor'} = undef;
$gdba->store($gdb);

my $sth = $compara_dba->prepare('SELECT genome_db_id
                                FROM genome_db
                                WHERE name = ? AND assembly = ?');
$sth->execute($gdb->name, $gdb->assembly);

ok($gdb->dbID && ($gdb->adaptor == $gdba));
debug("gdb->dbID = " . $gdb->dbID);

my ($id) = $sth->fetchrow_array;
$sth->finish;


ok($id && $id == $gdb->dbID);
debug("[$id] == [" . $gdb->dbID . "]?");

$multi->restore('compara', 'genome_db');



