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

package Bio::EnsEMBL::ExternalData::AttachedFormat;

use strict;
use warnings;
no warnings 'uninitialized';

use Text::ParseWords;

use EnsEMBL::Web::File::Utils::URL qw(get_filesize);

sub new {
  my ($proto,$hub,$format,$url,$trackline) = @_;
  my $class = ref($proto) || $proto;

  (my $new_class = $class) =~ s/ExternalData/Web::File/;
  $new_class =~ s/Bio:://;
  warn "######## DEPRECATED MODULE - please use $new_class instead";

  my $self = {
    format => $format,
    hub => $hub,
    url => $url,
    trackline => $trackline,
  };
  bless $self,$class;
  return $self;
}

sub name  { shift->{'format'} }
sub trackline { shift->{'trackline'} }

sub extra_config_page { return undef; }

sub check_data {
  my ($self) = @_;
  my $error_message = '';
  my $options = {};

  my $url = $self->{'url'};
  $url = "http://$url" unless $url =~ /^http|^ftp/;

  ## Check file size
  my $feedback = get_filesize($url, {'hub' => $self->{'hub'}, 'nice' => 1});
  my $error = $feedback->{'error'}[0];
  if ($error) {
    if ($error eq 'timeout') {
      $error_message = 'No response from remote server';
    } elsif ($error eq 'mime') {
      $error_message = 'Invalid mime type';
    } elsif ($error eq 'denied') {
      ## Server is refusing header requests, so do nothing
      $error = undef;
      $options = {'filesize' => 1};
    } else {
      $error = "Unable to access file. Server response: $feedback->{'error'}";
    }
  } elsif (defined $feedback->{'filesize'} && $feedback->{'filesize'} == 0) {
    $error = 'File appears to be empty';
  }
  else {
    $options = {'filesize' => $feedback->{'filesize'}};
  }
  return ($url, $error, $options);
}

sub parse_trackline {
  my %out = map { ( split /=/ )[(0,1)] } quotewords('\s',0,$_[1]);
  $out{'chrom'} =~ s/^chr// if exists $out{'chrom'};
  $out{'description'} = $out{'name'} unless exists $out{'description'};
  return \%out;
}

1;
