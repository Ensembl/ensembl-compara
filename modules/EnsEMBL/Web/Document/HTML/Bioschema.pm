=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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
  $server = 'https://'.$server unless ($server =~ /^http/);
  my $sitename = $sd->ENSEMBL_SITETYPE;

  my $data = {
              '@type' => 'DataCatalog',
              '@id'   => $catalog, 
              'name'  => 'Ensembl',
              'url'   => $server, 
              'keywords' => 'genomics, bioinformatics, vertebrate, EBI, genetic, research, gene, regulation, variation, tool, download',
              'http://purl.org/dc/terms/conformsTo' => {
                  '@id'   => "https://bioschemas.org/profiles/DataCatalog/0.3-RELEASE-2019_07_01/",
                  '@type' => "CreativeWork"
              },
              'dataset' => {
                            '@type' => 'Dataset',
                            '@id'   =>  "http://www.ensembl.org/#dataset",
                            'http://purl.org/dc/terms/conformsTo' => {
                                '@id'   => "https://bioschemas.org/profiles/Dataset/0.3-RELEASE-2019_06_14/",
                                '@type' => "CreativeWork"
                            },
                            'name'  =>  sprintf('%s Comparative Genomics Data', $sitename),
                            'includedInDataCatalog' => $catalog,
                            'url'   => 'http://www.ensembl.org/info/genome/compara/accessing_compara.html',
                            'license' => 'https://www.apache.org/licenses/LICENSE-2.0',
                            'description' => 'Gene trees, protein families and alignments across the vertebrate taxonomic space',
                            'keywords' => 'phylogenetics, evolution, homology, synteny',
                            'distribution'  => [{
                                                  '@type' => 'DataDownload',
                                                  'name'  => sprintf('%s Comparative Genomics - EMF files', $sitename),
                                                  'description' => 'Alignments of resequencing data for Ensembl vertebrate species',
                                                  'fileFormat' => 'emf',
                                                  'encodingFormat' => 'text/plain',
                                                  'contentURL'  => sprintf('%s/emf/ensembl-compara/', $sd->ENSEMBL_FTP_URL), 
                              }],
                          },
              'provider' => {
                              '@type' => 'Organization',
                              'name'  => 'Ensembl',
                              'email' => 'helpdesk@ensembl.org',
                            },
              'sourceOrganization' => {
                                        '@type' => 'Organization',
                                        'name'  => 'European Bioinformatics Institute',
                                        'url' => 'https://www.ebi.ac.uk',
                                      },
  };


  my $json_ld = create_bioschema($data);
  return $json_ld;
}


1;
