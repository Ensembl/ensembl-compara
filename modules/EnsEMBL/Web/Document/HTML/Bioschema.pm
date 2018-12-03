=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Document::HTML::Bioschema;

### Create bioschema markup, where appropriate 

use strict;

use EnsEMBL::Web::Utils::Bioschemas qw(create_bioschema);

use base qw(EnsEMBL::Web::Document::HTML);

sub render {
  my $self  = shift;
  my $sd    = $self->hub->species_defs;
  my $catalog = $sd->BIOSCHEMAS_DATACATALOG;
  return unless $catalog;

  my $server = $sd->ENSEMBL_SERVERNAME;
  $server = 'http://'.$server unless ($server =~ /^http/);
  my $sitename = $sd->ENSEMBL_SITETYPE;

  my $data = {
              '@type' => 'DataCatalog',
              '@id'   => $catalog, 
              'name'  => 'Ensembl Release',
              'url'   => $server, 
              'dataset' => {
                            '@type' => 'Dataset',
                            'name'  =>  sprintf('%s Comparative Genomics Data', $sitename),
                            'includedInDataCatalog' => $catalog,
                            'url'   => 'http://www.ensembl.org/info/genome/compara/accessing_compara.html',
                            'distribution'  => [{
                                                  '@type' => 'DataDownload',
                                                  'name'  => sprintf('%s Comparative Genomics - EMF files', $sitename),
                                                  'fileFormat' => 'emf',
                                                  'contentURL'  => sprintf('%s/emf/ensembl-compara/', $sd->ENSEMBL_FTP_URL), 
                              }],
              'creator' => {
                            '@type' => 'Organization',
                            'name'  => 'Ensembl',
                        }
              },
              'provider' => {
                              '@type' => 'Organization',
                              'name'  => 'Ensembl',
                              'email' => 'helpdesk@ensembl.org',
              },
  };


  my $json_ld = create_bioschema($data);
  warn $json_ld;
  return $json_ld;
}


1;
