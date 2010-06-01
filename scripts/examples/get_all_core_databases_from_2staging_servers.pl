#!/usr/local/bin/perl -w

# Generates a list of Bio::EnsEMBL::DBSQL::DBAdaptor objects for all core databases found on two staging servers
# minus databases that contain ancestral sequences.

use strict;
use Bio::EnsEMBL::Registry;

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

print "\n------------[Found a total of ".scalar(@core_dbas)."core databases on staging servers]------------\n";
foreach my $dba (@core_dbas) {
    print 'dba_species: '.$dba->species()."\n";
}

