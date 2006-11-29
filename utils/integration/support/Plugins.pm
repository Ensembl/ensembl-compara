## If you wish to use the EnsEMBL web-code from the command line, you will
## need to hardcode the server root here

## $SiteDefs::ENSEMBL_SERVERROOT = '/path to root of ensembl tree';

$SiteDefs::ENSEMBL_PLUGINS = [
  'EnsEMBL::Sanger_head'=> $SiteDefs::ENSEMBL_SERVERROOT.'/sanger-plugins/head',
  'EnsEMBL::ecs2'=> $SiteDefs::ENSEMBL_SERVERROOT.'/sanger-plugins/ecs2',
  'EnsEMBL::Sanger_dev'=> $SiteDefs::ENSEMBL_SERVERROOT.'/sanger-plugins/dev',
  'EnsEMBL::Sanger'    => $SiteDefs::ENSEMBL_SERVERROOT.'/sanger-plugins/sanger',
  'EnsEMBL::Ensembl'   => $SiteDefs::ENSEMBL_SERVERROOT.'/public-plugins/ensembl'
];

1;

