#!/usr/local/bin/perl -w

# Connects to the staging servers, gets the list of current core databases (make sure you have the latest core API or it won't pick up any databases),
# matches them with ensembl-master's genome_db_ids and generates a list of hash entries that are suitable for loading using comparaLoadGenomes.pl script.

use strict;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

Bio::EnsEMBL::Registry->load_registry_from_multiple_dbs(
    {   '-host' => 'ens-staging.internal.sanger.ac.uk',
        '-port' => 3306,
        '-user' => 'ensro',
        '-pass' => '',
    },
    {   '-host' => 'ens-staging2.internal.sanger.ac.uk',
        '-port' => 3306,
        '-user' => 'ensro',
        '-pass' => '',
    },
);

my @core_dbas = grep { $_->species !~ /ancestral/i } @{ Bio::EnsEMBL::Registry->get_all_DBAdaptors( -group => 'core') };

my $gdb_adaptor = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
    '-host' => 'compara1.internal.sanger.ac.uk',
    '-port' => 3306,
    '-user' => 'ensro',
    '-pass' => '',
    '-dbname' => 'sf5_ensembl_compara_master',
)->get_GenomeDBAdaptor();

print STDERR "\n------------[Found a total of ".scalar(@core_dbas)."core databases on staging servers]------------\n";
foreach my $core_dba (sort { $a->species() cmp $b->species() } @core_dbas) {
    my $dbc       = $core_dba->dbc();
    my $genome_db = $gdb_adaptor->fetch_by_core_DBAdaptor($core_dba);

    print "  { TYPE => SPECIES,\n";
    print "\t'genome_db_id' => ".$genome_db->dbID().",\n";
    print "\t'taxon_id'     => ".$genome_db->taxon_id().",\n";
    print "\t'species'      => '".$core_dba->species()."',\n";
    print "\t'phylum'       => 'Unknown',\n";
    print "\t'module'       => 'Bio::EnsEMBL::DBSQL::DBAdaptor',\n";
    print "\t'host'         => '".$dbc->host()."',\n";
    print "\t'port'         => ".$dbc->port().",\n";
    print "\t'user'         => '".$dbc->username()."',\n";
    print "\t'pass'         => '".$dbc->password()."',\n";
    print "\t'dbname'       => '".$dbc->dbname()."',\n";
    print "  },\n";
}

print "  { TYPE => END }\n]\n";

