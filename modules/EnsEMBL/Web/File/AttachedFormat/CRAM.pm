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

package EnsEMBL::Web::File::AttachedFormat::CRAM;

use strict;
use warnings;
no warnings 'uninitialized';

use LWP::UserAgent;
use File::Basename qw(fileparse);
use File::Spec;
use File::stat qw(stat);

use EnsEMBL::Web::File::Utils::URL qw(chase_redirects);

use base qw(EnsEMBL::Web::File::AttachedFormat);

sub check_data {
  my ($self) = @_;
  my $url = $self->{'url'};
  my $error = '';
  require Bio::DB::HTS;

  $url = chase_redirects($url, {'hub' => $self->{'hub'}});

  if (ref($url) eq 'HASH') {
    $error = $url->{'error'}[0];
    warn "!!! ERROR ATTACHING CRAM: $error";
  }
  else {
    if ($url =~ /^ftp:\/\//i && !$self->{'hub'}->species_defs->ALLOW_FTP_BAM) {
      $error = "The cram file could not be added - FTP is not supported, please use HTTP.";
    }
    else {
      $self->_check_cached_index;
      # try to open and use the cram file and its index -
      # this checks that the cram and index files are present and correct,
      # and should also cause the index file to be downloaded and cached in /tmp/
      my ($hts, $hts_file, $index);
      eval
      {
        # Note the reason this uses Bio::DB::HTS->new rather than Bio::DB::Bam->open is to allow set up
        # of default cache dir (which happens in Bio::DB:HTS->new) -
        $hts = Bio::DB::HTS->new(-bam => $url);
        $hts_file = $hts->hts_file;
        $index = Bio::DB::HTSfile->index($hts) ;
        my $header = $hts->header;
        my $region = $header->target_name->[0];
        my $callback = sub {return 1};
        $index->fetch($hts_file, $header->parse_region("$region:1-10"), $callback);
      };
      warn $@ if $@;
      warn "Failed to open CRAM " . $url unless $hts_file;
      warn "Failed to open CRAM index for " . $url unless $index;

      if ($@ or !$hts_file or !$index) {
        $error = "Unable to open/index remote CRAM file: $url<br>Ensembl can only display sorted, indexed CRAM files.<br>Please ensure that your web server is accessible to the Ensembl site and both your CRAM and index files are present and publicly readable.<br>Your CRAM and index files must have the same name, with a .cram extension for the CRAM file, and a .cram.crai extension for the index file.";
      }
    }
  }
  return ($url, $error);
}

# Ensure there is no out-of-date cached CRAM index by deleting the local
# version if it exists and is older than the remote version. Samtools will
# then fetch a fresh copy of the index if needed.
sub _check_cached_index {
  my ($self) = @_;
  my $index_url = $self->{url} . '.crai';
  my $tmp_file  = File::Spec->tmpdir . '/' . fileparse($index_url);

  if (-f $tmp_file) {
    my $local_time  = int stat($tmp_file)->[9];
    my $remote_time = int eval { LWP::UserAgent->new->head($index_url)->last_modified };

    if ($local_time <= $remote_time) {
      warn "Cached CRAM index is older than remote - deleting $tmp_file";
      unlink $tmp_file;
    }
  }
}

1;
