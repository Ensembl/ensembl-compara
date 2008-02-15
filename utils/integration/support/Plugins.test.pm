
$SiteDefs::ENSEMBL_PLUGINS = [
    'EnsEMBL::Sanger_integration'  => $SiteDefs::ENSEMBL_SERVERROOT.'/sanger-plugins/integration',
    'EnsEMBL::Sanger_head'  => $SiteDefs::ENSEMBL_SERVERROOT.'/sanger-plugins/head',
    'EnsEMBL::Sanger_dev'   => $SiteDefs::ENSEMBL_SERVERROOT.'/sanger-plugins/dev',
    'EnsEMBL::Sanger'       => $SiteDefs::ENSEMBL_SERVERROOT.'/sanger-plugins/sanger',
    'EnsEMBL::Ensembl'      => $SiteDefs::ENSEMBL_SERVERROOT.'/public-plugins/ensembl',
];


1;

