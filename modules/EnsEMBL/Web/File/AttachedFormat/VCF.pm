=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::File::AttachedFormat::VCF;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::File::AttachedFormat);

use EnsEMBL::Web::File::Utils::URL qw(chase_redirects);

sub check_data {
  my ($self) = @_;
  my $url = $self->{'url'};
  my $error = '';
  require Bio::EnsEMBL::ExternalData::VCF::VCFAdaptor;

  $url = chase_redirects($url, {'hub' => $self->{'hub'}});
  if ($url =~ /^ftp:\/\//i && !$self->{'hub'}->species_defs->ALLOW_FTP_VCF) {
    $error = "The VCF file could not be added - FTP is not supported, please use HTTP.";
  } 
  else {
    # try to open and use the VCF file
    # this checks that the VCF and index files are present and correct, 
    # and should also cause the index file to be downloaded and cached in /tmp/ 
    my ($dba, $index);
    eval {
      $dba =  Bio::EnsEMBL::ExternalData::VCF::VCFAdaptor->new($url);
      $dba->fetch_variations(1, 1, 10);
    };
    warn $@ if $@;
    warn "Failed to open VCF $url\n $@\n " if $@; 
    warn "Failed to open VCF $url\n $@\n " unless $dba;
          
    if ($@ or !$dba) {
      $error = qq{
        Unable to open/index remote VCF file: $url
        <br />Ensembl can only display sorted, indexed VCF files
        <br />Ensure you have sorted and indexed your file and that your web server is accessible to the Ensembl site 
        <br />For more information on the type of file expected please see the large file format <a href="/info/website/upload/large.html">documentation.</a>
      };
    }
  }
  return ($url, $error);
}

1;

