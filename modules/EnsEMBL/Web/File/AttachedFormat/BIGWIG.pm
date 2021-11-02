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

package EnsEMBL::Web::File::AttachedFormat::BIGWIG;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::File::AttachedFormat);
use EnsEMBL::Web::File::Utils::URL qw(chase_redirects);

sub extra_config_page { return "ConfigureGraph"; }

sub check_data {
  my ($self) = @_;
  my $url = $self->{'url'};
  my $error = '';
  require Bio::DB::BigFile;

  $url = chase_redirects($url, {'hub' => $self->{'hub'}});
  # try to open and use the bigwig file
  # this checks that the bigwig files is present and correct
  my $bigwig;
  eval {
    Bio::DB::BigFile->set_udc_defaults;
    $bigwig = Bio::DB::BigFile->bigWigFileOpen($url);
    my $chromosome_list = $bigwig->chromList;
  };
  my $error;
  if (ref $url eq 'HASH' && $url->{'error'} && scalar @{$url->{'error'}}) {
    $error = join(', ', @{$url->{'error'}});
  }

  if ($@ or $error or !$bigwig) {
    $error = 'Unknown error' unless $error;
    my $warning = "Failed to open bigWig $original_url ($error)";
    $message = "$warning<br>Ensure that your web/ftp server is accessible to the Ensembl site";
    $warning .= ": $@" if $@;
    warn $warning;
  }
  return ($url, $message);
}


1;
