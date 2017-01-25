=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2017] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

## If you wish to use the EnsEMBL web-code from the command line, you will
## need to hardcode the server root here

## $SiteDefs::ENSEMBL_SERVERROOT = '/path to root of ensembl tree';

$SiteDefs::ENSEMBL_PLUGINS = [
    'EnsEMBL::Sanger_head'  => $SiteDefs::ENSEMBL_SERVERROOT.'/sanger-plugins/head',
    'EnsEMBL::Sanger_dev'   => $SiteDefs::ENSEMBL_SERVERROOT.'/sanger-plugins/dev',
    'EnsEMBL::Sanger'       => $SiteDefs::ENSEMBL_SERVERROOT.'/sanger-plugins/sanger',
    'EnsEMBL::Ensembl'      => $SiteDefs::ENSEMBL_SERVERROOT.'/public-plugins/ensembl',
];


1;

