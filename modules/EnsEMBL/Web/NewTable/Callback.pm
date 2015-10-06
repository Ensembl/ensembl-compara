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

package EnsEMBL::Web::NewTable::Callback;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::NewTable::Endpoint);

use JSON qw(from_json);

use CGI::Cookie;
use MIME::Base64;
use Compress::Zlib;
use Digest::MD5 qw(md5_hex);
use SiteDefs;
use Text::CSV;

use EnsEMBL::Web::NewTable::Config;
use EnsEMBL::Web::Procedure;
use EnsEMBL::Web::NewTable::Phase;

# XXX move all this stuff to somewhere it's more suited

sub compress_block {
  return encode_base64(compress(JSON->new->encode($_[0])));
}

sub uncompress_block {
  return JSON->new->decode(uncompress(decode_base64($_[0])));
}

sub new {
  my ($proto,$hub,$component) = @_;

  my $class = ref($proto) || $proto;
  my $self = $class->SUPER::new($hub,$component);
  $self = { %$self, (
    # NOT RESET EACH PHASE
    hub => $hub,
    component => $component,
    enum_values => {},
    out => [],
    # RESET EACH PHASE
    request_num => 0,
    null_cache => [],
    sort_data => [],
    stand_down => 0,
    phase_rows => undef,
  )};
  bless $self,$class;
  return $self;
}

sub finish_enum {
  my ($self,$row) = @_;

  my %enums;
  foreach my $colkey (@{$self->{'wire'}{'enumerate'}||[]}) {
    my $column = $self->{'config'}->column($colkey);
    $enums{$colkey} = $column->range($self->{'enum_values'}{$colkey}||{});
  }
  return \%enums;
}

sub go {
  my ($self) = @_;

  my $hub = $self->{'hub'};
  my $config = from_json($hub->param('config'));
  my $ssplugins = from_json($hub->param('ssplugins'));
  my $keymeta = from_json($hub->param('keymeta'));
  $self->{'config'} = EnsEMBL::Web::NewTable::Config->new($self,$config,$ssplugins,$keymeta);
  $self->{'orient'} = from_json($hub->param('orient'));
  $self->{'wire'} = from_json($hub->param('wire'));
  my $more = JSON->new->allow_nonref->decode($hub->param('more'));
  my $incr_ok = ($hub->param('incr_ok')||'' eq 'true');
  # Add plugins

  my $proc = EnsEMBL::Web::Procedure->new($self->{'hub'},'callback');

  $proc->set_variables({
    orient => $self->{'orient'}, more => $more, incr_ok => $incr_ok,
    keymeta => $keymeta
  });
  my $out = $proc->go(sub {
    return $self->newtable_data_request($more,$incr_ok,$keymeta);
  });
  if($self->{'wire'}{'format'} eq 'export') {
    $out = $self->convert_to_csv($out);
    my $r = $hub->apache_handle;
    # TODO find bits of ensembl which can do this as we do
    $r->content_type('application/octet-string');
    my $cookie = CGI::Cookie->new(-name  => 'spawntoken',
                                  -value => $hub->param('spawntoken'));
    $r->headers_out->add('Set-Cookie' => $cookie);
    $r->headers_out->add('Content-Disposition' => sprintf 'attachment; filename=%s.csv', $hub->param('filename')||'ensembl-export');
  }
  return $out;
}

sub preload {
  my ($self,$table,$config) = @_;

  $self->{'config'} = $table->config;
  $self->{'wire'} = $table->config->orient_out;
  $self->{'orient'} = $table->config->orient_out;
  my $proc = EnsEMBL::Web::Procedure->new($self->{'hub'},'preload');
  $proc->set_variables({ orient => $self->{'orient'}, config => $config });
  return $proc->go(sub {
    return $self->newtable_data_request(undef,1);
  }); 
}

sub convert_to_csv {
  my ($self,$data) = @_;

  my $out = '';
  my $csv = Text::CSV->new({ binary => 1 });
  $self->convert($data,sub {
    my ($row) = @_;
    $csv->combine(@$row);
    $out .= $csv->string()."\n";
  });
  return $out; 
}

sub run_phase {
  my ($self,$phase,$keymeta) = @_;

  my $era = $phase->{'era'};
  $phase->{'cols'} ||= $self->{'config'}->columns;
  my $start = ($self->{'req_lengths'}{$era}||=0); 

  # Populate
  my $p = EnsEMBL::Web::NewTable::Phase->new($self->{'component'},$self,$phase,$start,($self->{'shadow_lengths'}{$era}||=0),$self->size_needed,$self->{'config'},$self->{'wire'});
  my $out = $p->go();

  push @{$self->{'out'}},$out->{'out'};

  # Move on continuation counters
  $self->{'req_lengths'}{$era} = $out->{'request_num'};
  $self->{'shadow_lengths'}{$era} = $out->{'shadow_num'};
}

sub convert {
  my ($self,$output,$fn) = @_;

  my $ob_size = 10000;
  my (@series,%rseries,@outblock);
  my $outblock = -1;
  my $rows = [];
  foreach my $resp (@{$output->{'responses'}}) {
    # Columns
    foreach my $col (@{$resp->{'series'}}) {
      next if exists $rseries{$col};
      push @series,$col;
      $rseries{$col} = $#series;
    }
    # Data
    foreach my $block (0..$#{$resp->{'len'}}) {
      my $data = uncompress_block($resp->{'data'}[$block]);
      my $null = uncompress_block($resp->{'nulls'}[$block]);
      foreach my $row (0..$resp->{'len'}[$block]-1) {
        my $rownum = $resp->{'start'}+$row;
        my $new_ob = int($rownum/$ob_size);
        my $offset = $rownum-($new_ob*$ob_size);
        if($outblock != $new_ob) {
          $outblock[$outblock] = compress_block($rows) if $outblock != -1;
          $outblock = $new_ob;
          if($outblock[$outblock]) {
            $rows = uncompress_block($outblock[$outblock]);
          } else {
            $rows = [];
          }
        }
        my @row;
        foreach my $i (0..$#{$resp->{'series'}}) {
          next if $null->[$i][$row];
          $row[$rseries{$resp->{'series'}[$i]}] = $data->[$i][$row];
        }
        $rows->[$offset] = \@row;
      }
    }
  }
  $outblock[$outblock] = compress_block($rows) if $outblock != -1;
  $fn->(\@series);
  foreach my $outblock (@outblock) {
    my $rows = uncompress_block($outblock);
    foreach my $row (@$rows) {
      $fn->($row);
    }
  }
}

sub newtable_data_request {
  my ($self,$more,$incr_ok,$keymeta) = @_;

  # Check if we need to request all rows due to sorting
  my $all_data = 0;
  if($self->{'wire'}{'sort'} and @{$self->{'wire'}{'sort'}}) {
    $all_data = 1;
  }
  
  my %shadow = %{$self->{'orient'}};
  delete $shadow{'filter'};
  delete $shadow{'pagerows'};
  delete $shadow{'series'};

  my $phase;
  if(defined $more) {
    $phase = $more->{'phase'};
    $self->{'req_lengths'} = $more->{'req_lengths'};
    $self->{'shadow_lengths'} = $more->{'shadow_lengths'};
  }
  
  my $num_phases = $self->{'config'}->num_phases();
  if($incr_ok && !$all_data) {
    my $start = time();
    my $end = $start;
    while($end-$start < 3 && $phase < $num_phases) {
      $self->run_phase($self->{'config'}->phase($phase),$keymeta);
      $end = time();
      $phase++;
    }
  } else {
    $self->run_phase($self->{'config'}->phase($_),$keymeta) for (0..$num_phases-1);
    $phase = $num_phases;
  }

  $more = {
    phase => $phase,
    req_lengths => $self->{'req_lengths'},
    shadow_lengths => $self->{'shadow_lengths'}
  };
  $more = undef if $phase == $num_phases;
  return {
    responses => $self->{'out'},
    keymeta => $self->{'key_meta'},
    shadow => \%shadow,
    enums => $self->finish_enum(),
    orient => $self->{'orient'},
    more => $more,
  };
}

1;
