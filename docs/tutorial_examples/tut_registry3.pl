use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor

my $host   = 'ensembldb.ensembl.org';
my $user   = 'anonymous';
my $port   = 5306;
my $dbname = 'ensembl_compara_51';

my $comparadb= new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(
    -host   => $host,
    -port   => $port,
    -user   => $user,
    -dbname => $dbname,
);
