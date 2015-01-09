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

package Bio::EnsEMBL::ExternalData::AttachedFormat::BIGWIG;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(Bio::EnsEMBL::ExternalData::AttachedFormat);
use EnsEMBL::Web::File::Utils::URL qw(chase_redirects);

sub extra_config_page { return "ConfigureBigWig"; }

sub check_data {
  my ($self) = @_;
  my $url = $self->{'url'};
  my $error = '';
  require Bio::DB::BigFile;

  $url = chase_redirects($url, {'hub' => $self->{'hub'}});
  if ($url =~ /^ftp:\/\//i && !$self->{'hub'}->species_defs->ALLOW_FTP_BIGWIG) {
    $error = "The BigWig file could not be added - FTP is not supported, please use HTTP.";
  }
  else {
    # try to open and use the bigwig file
    # this checks that the bigwig files is present and correct
    my $bigwig;
    eval {
      Bio::DB::BigFile->set_udc_defaults;
      $bigwig = Bio::DB::BigFile->bigWigFileOpen($url);
      my $chromosome_list = $bigwig->chromList;
    };
    warn $@ if $@;
    warn "Failed to open BigWig " . $url unless $bigwig;

    if ($@ or !$bigwig) {
      $error = "Unable to open remote BigWig file: $url<br>Ensure that your web/ftp server is accessible to the Ensembl site";
    }
  }
  return $error;
}


1;
