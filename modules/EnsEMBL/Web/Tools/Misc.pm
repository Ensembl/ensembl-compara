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

package EnsEMBL::Web::Tools::Misc;

## Just a bunch of useful tools
use strict;

use base qw(Exporter);

use constant 'MAX_HIGHLIGHT_FILESIZE' => 1048576;  # (bytes) = 1Mb

our @EXPORT = our @EXPORT_OK = qw(pretty_date style_by_filesize champion);

sub pretty_date {
  my $timestamp = shift;
  my @date = localtime($timestamp);
  my @days = ('Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat');
  my @months = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');
  return $days[$date[6]].' '.$date[3].' '.$months[$date[4]].', '.($date[5] + 1900);
}

# Computes given score on each member of list and returns member with highest
sub champion(&@) {
  my $f = shift;
  my ($champion,$best);
  foreach(@_) {
    my $v = $f->($_);
    if(!defined $best or $best < $v) {
      $champion = $_;
      $best = $v;
    }
  }
  return $champion;
}

sub style_by_filesize {
  my $filesize     = shift || 0;
  my $max_filesize = MAX_HIGHLIGHT_FILESIZE;
  return $filesize > $max_filesize ? 'density_line' : 'highlight_lharrow';
}

1;
