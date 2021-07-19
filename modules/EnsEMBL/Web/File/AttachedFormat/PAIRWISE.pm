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

package EnsEMBL::Web::File::AttachedFormat::PAIRWISE;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::File::AttachedFormat);

use EnsEMBL::Web::IOWrapper::Indexed; 

use EnsEMBL::Web::File::Utils::URL qw(chase_redirects);

sub check_data {
  my ($self) = @_;
  my $url = $self->{'url'};
  my $error = '';

  $url = chase_redirects($url, {'hub' => $self->{'hub'}});
  
  # try to open and use the Pairwise file
  # this checks that the Pairwise and index files are present and correct, 
  # and should also cause the index file to be downloaded and cached in /tmp/ 
  my $args = {'options' => {'hub' => $self->{'hub'}}};
  my $iow = eval { EnsEMBL::Web::IOWrapper::Indexed::open($url, 'PairwiseTabix', $args); };

  unless ($iow) {
    warn "Failed to open Pairwise $url\n$@\n";
    $error = qq{
        Unable to open/index remote Pairwise file: $url
        <br />Ensembl can only display sorted, indexed Pairwise files
        <br />Ensure you have sorted and indexed your file and that your web server is accessible to the Ensembl site 
        <br />For more information on the type of file expected please see the large file format <a href="/info/website/upload/large.html">documentation.</a>
    };
  }
  return ($url, $error);
}

1;

