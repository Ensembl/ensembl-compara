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

package EnsEMBL::Web::File::AttachedFormat;

use strict;
use warnings;
no warnings 'uninitialized';

use Text::ParseWords;

use EnsEMBL::Web::File::Utils::URL qw(get_filesize);

sub new {
  my ($proto, %args) = @_;
  my $class = ref($proto) || $proto;
  my $self = \%args;
  bless $self,$class;
  return $self;
}

sub url       { return shift->{'url'} }
sub trackline { shift->{'trackline'} }

sub name {
  my $self = shift;
  unless ($self->{'format'}) {
    my @namespace = split('::', ref($self));
    $self->{'format'} = $namespace[-1];
  }
  return $self->{'format'};
}

sub extra_config_page { return undef; }

sub check_data {
  my ($self) = @_;
  my $error = '';
  my $options = {};

  my $url = $self->{'url'};
  $url = "http://$url" unless $url =~ /^http|^ftp/;

  ## Check file size
  my $feedback = get_filesize($url, {'hub' => $self->{'hub'}, 'nice' => 1});

  if ($feedback->{'error'}) {
    my $errors = ref($feedback->{'error'}) eq 'ARRAY' ? join('; ', @{$feedback->{'error'}}) : $feedback->{'error'};
    if ($errors eq 'timeout') {
      $error = 'No response from remote server';
    } elsif ($errors eq 'mime') {
      $error = 'Invalid mime type';
    } else {
      $error = "Unable to access file. Server response: $errors";
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
