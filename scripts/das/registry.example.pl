use strict;
use Bio::EnsEMBL::Utils::ConfigRegistry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-host => 'ensembldb.ensembl.org',
                                            -user => 'anonymous',
                                            -port => 3306,
                                            -species => 'ensembl_compara_41',
                                            -dbname => 'ensembl_compara_41');

1;
