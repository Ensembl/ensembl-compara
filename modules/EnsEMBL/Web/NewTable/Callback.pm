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

package EnsEMBL::Web::NewTable::Callback;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::NewTable::Endpoint);

use JSON qw(from_json);

use CGI::Cookie;
use Digest::MD5 qw(md5_hex);
use Text::CSV;

use EnsEMBL::Web::NewTable::Config;
use EnsEMBL::Web::NewTable::Convert;
use EnsEMBL::Web::NewTable::Phase;

# XXX move all this stuff to somewhere it's more suited

sub new {
  my ($proto,$hub,$component) = @_;

  my $class = ref($proto) || $proto;
  my $self = $class->SUPER::new($hub,$component);
  $self = { %$self, (
    hub => $hub,
    component => $component,
    out => [],
  )};
  bless $self,$class;
  return $self;
}

sub go {
  my ($self) = @_;

  my $hub = $self->{'hub'};
  my $config = from_json($hub->param('config'));
  my $ssplugins = from_json($hub->param('ssplugins'));
  my $keymeta = from_json($hub->param('keymeta'));

  $self->{'config'} = EnsEMBL::Web::NewTable::Config->new($hub,$config,$ssplugins,$keymeta);

  my $activity = $hub->param('activity');
  if($activity) {
    my $act = $self->{'config'}->activity($activity);
    my $out = {};
    $out = $act->($self,$self->{'config'}) if $act;
    return $out;
  }
  $self->{'orient'} = from_json($hub->param('orient'));
  $self->{'wire'} = from_json($hub->param('wire'));
  my $more = JSON->new->allow_nonref->decode($hub->param('more'));

  my $out = $self->newtable_data_request($more,$keymeta,0);
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
  return $self->newtable_data_request(undef,undef,1);
}

sub convert_to_csv {
  my ($self,$data) = @_;

  my $out = '';
  my $csv = Text::CSV->new({ binary => 1 });
  my $convert = EnsEMBL::Web::NewTable::Convert->new(1);
  $convert->add_response($_) for @{$data->{'responses'}};
  my @headings;
  foreach my $key (@{$convert->series}) {
    my $col = $self->{'config'}->column($key);
    my $label = $col->get_label();
    $label =~ s/[\000-\037]//g;
    push @headings,$label;
  }
  $csv->combine(@headings);
  $out .= $csv->string()."\n";
  $convert->run(sub {
    my ($row) = @_;
    $csv->combine(@$row);
    $out .= $csv->string()."\n";
  });
  return $out; 
}

sub preflight_extensions {
  my ($self) = @_;

  $self->{'extensions'} = [];
  $self->{'unwire'} = { %{$self->{'wire'}} };
  foreach my $p (values %{$self->{'config'}->plugins}) {
    next unless $p->can('extend_response');
    my $pp = $p->extend_response($self->{'config'},$self->{'unwire'},$self->{'config'}->keymeta);
    next unless defined $pp;
    push @{$self->{'extensions'}},$pp;
    delete $self->{'wire'}{$pp->{'solves'}} if defined $pp->{'solves'};
  }
}

sub run_extensions {
  my ($self,$responses) = @_;

  my $plugins = $self->{'extensions'};
  $_->{'pre'}->() for @$plugins;
  my $convert = EnsEMBL::Web::NewTable::Convert->new(0); 
  $convert->add_response($_) for @$responses;
  $convert->run(sub { $_->{'run'}->($_[0]) for @$plugins; });
  foreach my $p (@$plugins) {
    my $out = $p->{'post'}->();
    $self->{'response'}{$p->{'name'}} = $out if $p->{'name'};
  }
}

sub merge_enum {
  my ($self,$into,$more) = @_;

  foreach my $colkey (@{$self->{'wire'}{'enumerate'}}) {
    my $column = $self->{'config'}->column($colkey);
    $into->{$colkey} = $column->merge_values($into->{$colkey}||{},$more->{$colkey}||{});
  }
}

sub run_phase {
  my ($self,$phase,$keymeta) = @_;

  my $era = $phase->{'era'};
  my $req_start = $era ? ($self->{'req_lengths'}{$era}||=0) : 0;
  my $shadow_start = $era ? ($self->{'shadow_lengths'}{$era}||=0) : 0;

  $req_start = 0+$req_start;

  # Populate
  my $out = EnsEMBL::Web::NewTable::Phase->new(
    $self->{'component'},$phase,$req_start,
    $shadow_start,$self->{'config'},$self->{'wire'}
  )->go();

  push @{$self->{'out'}},$out->{'out'};

  if ($era) {
    $self->{'req_lengths'}{$era} = $out->{'request_num'};
    $self->{'shadow_lengths'}{$era} = $out->{'shadow_num'};
  }
}

sub newtable_data_request {
  my ($self,$more,$keymeta,$one_phase) = @_;

  # Check if we need to request all rows due to sorting
  my $all_data = 0;
  if($self->{'wire'}{'sort'} and @{$self->{'wire'}{'sort'}}) {
    $all_data = 1;
  }
  if($self->{'wire'}{'format'} eq 'export') {
    $all_data = 1;
  }
 
  $self->preflight_extensions();
 
  my %shadow = %{$self->{'orient'}};
  delete $shadow{'filter'};
  delete $shadow{'pagerows'};
  delete $shadow{'series'};

  my $phase = 0;
  if(defined $more) {
    $phase = $more->{'phase'};
    $self->{'req_lengths'} = $more->{'req_lengths'};
    $self->{'shadow_lengths'} = $more->{'shadow_lengths'};
  }
  
  my $num_phases = $self->{'config'}->num_phases();
  if(!$all_data) {
    my $start = time();
    my $end = $start;
    while($end-$start < 3 && $phase < $num_phases) {
      $self->run_phase($self->{'config'}->phase($phase),$keymeta);
      $end = time();
      $phase++;
      last if $one_phase;
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
  $self->{'response'} = {};
  $self->run_extensions($self->{'out'});
  $self->{'response'} = {
    %{$self->{'response'}},
    responses => $self->{'out'},
    keymeta => $self->{'config'}->keymeta,
    shadow => \%shadow,
    orient => $self->{'orient'},
    more => $more,
  };
  return $self->{'response'};
}

1;
