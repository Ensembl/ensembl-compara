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

package EnsEMBL::Draw::Data::Test;

### A module to use with unit tests - returns some prepackaged data
### instead of taking input from a db or file

use strict;

use parent qw(EnsEMBL::Draw::Data);

sub get_data {
### Sample data for testing - replace with your own data if required!
### @return   Arrayref of "features"
  my $self = shift;
  
  return [
          {
            'seq_region'  => '19',
            'start'       => '6511775',
            'end'         => '6705060',
            'strand'      => 1,
          },
          {
            'seq_region'  => '19',
            'start'       => '6587568',
            'end'         => '6755620',
            'strand'      => 1,
          },
          {
            'seq_region'  => '19',
            'start'       => '6587641',
            'end'         => '6764481',
            'strand'      => 1,
          },
          {
            'seq_region'  => '19',
            'start'       => '6603909',
            'end'         => '6764455',
            'strand'      => 1,
          },
          {
            'seq_region'  => '19',
            'start'       => '6625260',
            'end'         => '6722355',
            'strand'      => 1,
          },
        ];
}

sub select_output {
  my ($self, $style) = @_;
  my %lookup = (
                'normal' => 'Blocks',
                );
  return $lookup{$style};
}

1;
