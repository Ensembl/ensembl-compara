=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

use LWP::UserAgent;
use File::Basename qw(fileparse);
use File::Spec;
use File::stat qw(stat);

use base qw(EnsEMBL::Web::File::AttachedFormat);

use EnsEMBL::Web::File::Utils::URL qw(chase_redirects);

sub check_data {
  my ($self) = @_;
  my $url = $self->{'url'};
  my $error = '';
  require Bio::DB::HTS::VCF;

  my $url_check = chase_redirects($url, {'hub' => $self->{'hub'}});
  
  if (ref($url_check) eq 'HASH') {
    $error = $url_check->{'error'}[0];
  }
  else {
    $self->_check_cached_index;
    # try to open and use the vcf file and its index -
    # this checks that the vcf and index files are present and correct, 
    # and should also cause the index file to be downloaded and cached in /tmp/ 
    my ($hts, $hts_file);
    eval {
      $hts          = Bio::DB::HTS::VCF->new( filename => $url);
      $hts_file     = $hts->{'vcf_file'};
    };
    warn $@ if $@;
    warn "Failed to open VCF " . $url unless $hts_file;

    if ($@ or !$hts_file) { 
      $error = qq{
        Unable to open/index remote VCF file: $url
        <br />Ensembl can only display sorted, indexed VCF files (unless you upload them directly from your computer).
        <br />Ensure you have sorted and indexed your file and that your web server is accessible to the Ensembl site 
        <br />For more information on the type of file expected please see the large file format <a href="/info/website/upload/large.html">documentation.</a>
      };
    }
  }

  return ($url, $error);
}

# Ensure there is no out-of-date cached VCF index by deleting the local 
# version if it exists and is older than the remote version. HTSlib will
# then fetch a fresh copy of the index if needed.
sub _check_cached_index {
  my ($self) = @_;
  my $index_url = $self->{url} . '.tbi';
  my $tmp_file  = File::Spec->tmpdir . '/' . fileparse($index_url);

  if (-f $tmp_file) {
    my $local_time  = int stat($tmp_file)->[9];
    my $remote_time = int eval { LWP::UserAgent->new->head($index_url)->last_modified };

    if ($local_time <= $remote_time) {
      warn "Cached VCF index is older than remote - deleting $tmp_file";
      unlink $tmp_file;
    }
  }
}


1;

