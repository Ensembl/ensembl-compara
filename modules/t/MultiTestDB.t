use Test;
use strict;

BEGIN { $| = 1; plan tests => 9 }

use Bio::EnsEMBL::Test::MultiTestDB;

ok(1);

# Database will be dropped when this
# object goes out of scope
my $multi = Bio::EnsEMBL::Test::MultiTestDB->new('multi');

ok($multi);

my $dba = $multi->get_DBAdaptor('compara');

ok($dba);

my $sth = $dba->dbc->prepare("select * from genome_db");
$sth->execute;

ok(scalar($sth->rows) == 12);


# now hide the gene table i.e. make an empty version of it
$multi->hide("compara","genome_db");
$sth->execute;
ok($sth->rows == 0);


# restore the gene table
$multi->restore();
$sth->execute;
ok(scalar($sth->rows) == 12);


# now save the gene table i.e. make a copy of it
$multi->save("compara","genome_db");
$sth->execute;
ok(scalar($sth->rows) == 12);


# delete 1 entry from the db
$sth = $dba->dbc->prepare("delete from genome_db where genome_db_id >= 12");
$sth->execute;

$sth = $dba->dbc->prepare("select * from genome_db");
$sth->execute;

ok(scalar($sth->rows) == 11);


# check to see whether the restore works again
$multi->restore();
$sth->execute;
ok(scalar($sth->rows) == 12);


$sth->finish;


