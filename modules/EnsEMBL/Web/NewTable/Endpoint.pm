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

package EnsEMBL::Web::NewTable::Endpoint;

# There's some stuff that's common to Callback and NewTable because both
# are ultimately concerned with communicating to the client whether that's
# a JSON callback (Callback) or the initial setup (NewTable). That's why
# they both inherit from this package (Endpoint) and that stuff goes
# here.

use strict;
use warnings;

use Carp;
use EnsEMBL::Web::Utils::DynamicLoader qw(dynamic_require);

use EnsEMBL::Web::NewTable::Cache;

our @PLUGINS = qw(Core Frame Decorate Filter Misc);

sub new {
  my ($proto,$hub,$component) = @_;

  my $class = ref($proto) || $proto;
  my $self = {
    key_meta => {},
    cache => EnsEMBL::Web::NewTable::Cache->new($hub),
  };
  bless $self,$class;
  return $self;
}

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

sub register_key {
  my ($self,$key,$meta) = @_;

  $self->{'key_meta'}{$key}||={};
  foreach my $k (keys %{$meta||{}}) {
    $self->{'key_meta'}{$key}{$k} = $meta->{$k} unless exists $self->{'key_meta'}{$key}{$k};
  } 
}

sub add_plugin {
  my ($self,$plugin,$conf,$_ours) = @_;

  $_ours ||= {};
  return undef unless $PLUGINS{$plugin};
  my $pp = $self->{'plugins'}{$plugin};
  $self->{'plugins'}{$plugin} = $PLUGINS{$plugin}->new($self) unless $pp;
  $pp = $self->{'plugins'}{$plugin};
  return undef unless $pp;
  $pp->configure($conf);
  foreach my $sub (@{$pp->requires()}) {
    next if $_ours->{$sub};
    $_ours->{$sub} = 1;
    $self->add_plugin($sub,$conf,$_ours);
  }
}

sub plugins {
  my ($self) = @_;

  my %out;
  foreach my $plugin (keys %{$self->{'plugins'}}) {
    $out{$plugin} = $self->{'plugins'}{$plugin}{'conf'};
  }
  return \%out;
}

sub can_delegate {
  my ($self,$type,$fn) = @_;

  $fn = "${type}_$fn" if $type;
  foreach my $plugin (values %{$self->{'plugins'}}) {
    if($plugin->can($fn)) {
      return 1;
    }
  }
  return 0;
}

sub delegate {
  my ($self,$obj,$type,$fn,$data) = @_;

  my $orig_fn = $fn;
  $fn = "${type}_$fn" if $type;
  foreach my $plugin (values %{$self->{'plugins'}}) {
    if($plugin->can($fn)) {
      return $plugin->$fn($obj,@$data);
    }
  }
  confess "No such method '$orig_fn'";
}

sub hub { return $_[0]->{'hub'}; }

1;
