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

package EnsEMBL::Web::File::AttachedFormat::PAIRWISE;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::File::AttachedFormat);

use Bio::EnsEMBL::IO::Adaptor::PairwiseAdaptor;

use EnsEMBL::Web::File::Utils::URL qw(chase_redirects);

sub _pairwise_adaptor {
  my ($self,$pwa) = @_;
  if (defined($pwa)) {
    $self->{'_cache'}->{'pairwise_adaptor'} = $pwa;
  } elsif (!$self->{'_cache'}->{'pairwise_adaptor'}) {
    $self->{'_cache'}->{'pairwise_adaptor'} = Bio::EnsEMBL::IO::Adaptor::PairwiseAdaptor->new($self->{'url'});
  }
  return $self->{'_cache'}->{'pairwise_adaptor'};
}

sub check_data {
  my ($self) = @_;
  my $url = $self->{'url'};
  my $error = '';

  $url = chase_redirects($url, {'hub' => $self->{'hub'}});
  if ($url =~ /^ftp:\/\//i && !$self->{'hub'}->species_defs->ALLOW_FTP_ALL) {
    $error = "The Pairwise file could not be added - FTP is not supported, please use HTTP.";
  } 
  else {
    # try to open and use the Pairwise file
    # this checks that the Pairwise and index files are present and correct, 
    # and should also cause the index file to be downloaded and cached in /tmp/ 
    my ($dba, $index);
    eval {
      $dba =  Bio::EnsEMBL::IO::Adaptor::PairwiseAdaptor->new($url);
    };
    warn $@ if $@;
    warn "Failed to open Pairwise $url\n $@\n " if $@; 
    warn "Failed to open Pairwise $url\n $@\n " unless $dba;
          
    if ($@ or !$dba) {
      $error = qq{
        Unable to open/index remote Pairwise file: $url
        <br />Ensembl can only display sorted, indexed Pairwise files
        <br />Ensure you have sorted and indexed your file and that your web server is accessible to the Ensembl site 
        <br />For more information on the type of file expected please see the large file format <a href="/info/website/upload/large.html">documentation.</a>
      };
    }
  }
  return ($url, $error);
}

1;

