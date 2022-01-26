=head1 sLICENSE

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

package EnsEMBL::Web::NewTable::NewTable;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::NewTable::Endpoint);
 
use JSON qw(from_json to_json);
use Scalar::Util qw(looks_like_number);

use EnsEMBL::Draw::Utils::ColourMap;

use HTML::Entities qw(encode_entities);

use EnsEMBL::Web::NewTable::Callback;
use EnsEMBL::Web::NewTable::Column;
use EnsEMBL::Web::NewTable::NewTableConfig;

sub new {
  my ($class, $component,$type) = @_;

  my $self = $class->SUPER::new($component->hub,$component);
  $self = { %$self, (
    component => $component,
    hub => $component->hub,
    phases    => [],
  )};

  bless $self, $class;

  $type  ||= ref($component);
  my $config = EnsEMBL::Web::NewTable::NewTableConfig->new($component->hub,undef,$type);
  $self->{'config'} = $config;

  # XXX these should be optional. That's why they're plugins! :-)
  $config->add_plugin('Core',{});
  $config->add_plugin('Frame',{});
  $config->add_plugin('Decorate',{});
  $config->add_plugin('Filter',{});
  $config->add_plugin('Misc',{});
#  $config->add_plugin('Paging',{});
  $config->add_plugin('Styles',{});
  $config->add_plugin('Sort',{});
  $config->add_plugin('State',{});

  return $self;
}

sub component { return $_[0]->{'component'}; }
sub has_rows { return !!@{$_[0]{'rows'}}; }
sub column { return $_[0]->{'config'}->column($_[1]); }

sub config { return $_[0]->{'config'}; }

sub get_plugin {
  my ($self,$plugin) = @_;

  return $self->{'plugins'}{$plugin};
}

sub add_phase {
  my ($self,$name,$era,$rows,$cols) = @_;

  $self->{'config'}->add_phase($name,$era,$rows,$cols);
}

sub render {
  my ($self,$hub,$component) = @_;

  my $data = $self->{'config'}->config;
  
  my $callback = EnsEMBL::Web::NewTable::Callback->new($hub,$component);
  $data->{'payload_one'} = $callback->preload($self,$data);

  $data = encode_entities(to_json($data));
  my $url = $component->ajax_url(undef,{},'ComponentAjax');
  return qq(
    <a class="new_table" href="$url">$data</a>
  );
}

sub add_columns {
  my ($self,$columns,$exclude) = @_;

  my %exclude;
  $exclude{$_}=1 for @$exclude;
  foreach my $col (@$columns) {
    next if $exclude{$col->{'_key'}};
    my %args = %$col;
    delete $args{'_key'};
    delete $args{'_type'};
    $self->{'config'}->add_column($col->{'_key'},$col->{'_type'},\%args);
  }
}

1;
