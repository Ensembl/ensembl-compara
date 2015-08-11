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

package EnsEMBL::Web::Component::NewTable;

use strict;

use JSON qw(from_json);

sub ajax_table_content {
  my ($self) = @_;

  my $hub = $self->hub;
  my $regions = from_json($hub->param('regions'));

  my $phases = [{ name => undef }];
  $phases = $self->incremental_table if $self->can('incremental_table');
  my @out;
  foreach my $region (@$regions) {
    my $columns = $region->{'columns'};
    my $more = $region->{'more'};

    my $iconfig = from_json($hub->param('config'));

    # Start row
    my $rows = $phases->[$more]{'rows'} || [0,-1];

    # Calculate columns to send
    my @cols = map { $_->{'key'} } @{$iconfig->{'columns'}};
    my %cols_pos;
    $cols_pos{$cols[$_]} = $_ for(0..$#cols);
    my $used_cols = $phases->[$more]{'cols'} || \@cols;
    my $columns_out = [ (0) x @cols ];
    $columns_out->[$cols_pos{$_}] = 1 for @$used_cols;

    # Populate data
    my $data = $self->table_content($phases->[$more]{'name'},$rows);
    my @data_out;
    foreach my $d (@$data) {
      push @data_out,[ map { $d->{$_}||'' } @$used_cols ];
    }

    # Move on continuation counter
    $more++;
    $more=0 if $more == @$phases;

    # Send it
    push @out,{
      request => $regions,
      data => \@data_out,
      region => { columns => $columns_out, start => $rows->[0] },
      more => $more,
    };
  }
  return \@out;
}

1;
