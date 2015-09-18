=head1 sLICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

use JSON qw(from_json);
use Scalar::Util qw(looks_like_number);

use EnsEMBL::Draw::Utils::ColourMap;

use base qw(EnsEMBL::Web::Root);
use HTML::Entities qw(encode_entities);

use EnsEMBL::Web::Utils::DynamicLoader qw(dynamic_require);
use EnsEMBL::Web::Utils::RandomString qw(random_string);

use EnsEMBL::Web::Document::NewTableSorts qw(newtable_sort_client_config);

our @PLUGINS = qw(Core Frame Decorate Filter Misc);

my %PLUGINS;
my @PACKAGES;
while(@PLUGINS) {
  my $plugin = shift @PLUGINS;
  my $package = dynamic_require("EnsEMBL::Web::NewTable::Plugins::$plugin",1);
  push @PACKAGES,$plugin;
  if($package) {
    my $children = $package->children();
    push @PLUGINS,@$children;
  }
}
foreach my $plugin (@PACKAGES) {
  my $package = "EnsEMBL::Web::NewTable::Plugins::$plugin";
  if(UNIVERSAL::isa($package,"EnsEMBL::Web::NewTable::Plugin")) {
    $PLUGINS{$plugin} = $package;
  }
}

sub new {
  my ($class, $component, $options) = @_;

  $options  ||= {};

  my $self = {
    component  => $component,
    columns    => [],
    options    => $options,
    plugins => {},
  };

  bless $self, $class;

  $self->preprocess_hyphens;

  return $self;
}

sub has_rows { return ! !@{$_[0]{'rows'}}; }

# \f -- optional hyphenation point
# \a -- optional break point (no hyphen)
sub hyphenate {
  my ($self, $data, $key) = @_;

  return unless exists $data->{$key};

  my $any = ($data->{$key} =~ s/\f/&shy;/g | $data->{$key} =~ s/\a/&#8203;/g);

  return $any;
}

sub preprocess_hyphens {
  my $self = shift;

  foreach (@{$self->{'columns'}}) {
    my $h = $_->{'label'} ? $self->hyphenate($_, 'label') : 0;
    $_->{'class'} .= ' hyphenated' if $h;
  }
}

sub add_plugin {
  my ($self,$plugin,$conf,$_ours) = @_;

  $_ours ||= {};
  return undef unless $PLUGINS{$plugin};
  my $pp = $self->{'plugins'}{$plugin};
  $self->{'plugins'}{$plugin} = $pp = $PLUGINS{$plugin}->new() unless $pp;
  return undef unless $pp;
  $pp->configure($conf);
  foreach my $sub (@{$pp->requires()}) {
    next if $_ours->{$sub};
    $_ours->{$sub} = 1;
    $self->add_plugin($sub,$conf,$_ours);
  }
}

sub render {
  my ($self,$hub) = @_;

  $self->add_plugin('Core',{});
  $self->add_plugin('Frame',{});
  $self->add_plugin('Decorate',{});
  $self->add_plugin('Filter',{});
  $self->add_plugin('Misc',{});
  $self->add_plugin('PageSizer',{});
  $self->add_plugin('Styles',{});

  return unless @{$self->{'columns'}};

  my $widgets = {};
  foreach my $p (keys %{$self->{'plugins'}}) {
    $widgets->{$p} = [
      $self->{'plugins'}{$p}->js_plugin,
      $self->{'plugins'}{$p}->js_config,
    ];
  }

  my $options     = $self->{'options'}        || {};
  my %table_class = map { $_ => 1 } split ' ', $options->{'class'};
  my $class   = join ' ', keys %table_class;

  my $url = $hub->url('ComponentAjax', {
    source => 'enstab',
    action => 'Web',
    function => 'VariationTable',
  },0,1);

  my %colmap;
  foreach my $i (0..$#{$self->{'columns'}}) {
    $colmap{$self->{'columns'}[$i]{'key'}} = $i;
  }

  my $sort_conf = newtable_sort_client_config(\%colmap,$self->{'columns'});

  my $orient = {
    format => 'Tabular',
  };
  my $data = {
    unique => random_string(32),
    type => $self->{'options'}{'type'}||'',
    cssclass => $class,
    columns => [ map { $_->{'key'} } @{$self->{'columns'}} ],
    orient => $orient,
    formats => [ "tabular", "paragraph" ],
    colconf => $sort_conf,
    widgets => $widgets,
  };
  my $payload_one = $self->{'component'}->newtable_data_request($data,$orient,$orient,undef,1);
  $data->{'payload_one'} = $payload_one;

  $data = encode_entities($self->jsonify($data));
  return qq(
    <a class="new_table" href="$url">$data</a>
  );
}

sub add_column {
  my ($self,$key,$options) = @_;

  push @{$self->{'columns'}},{ key => $key, %{$options||{}} };
}

1;
