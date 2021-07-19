=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::NewTable::Plugin;

use strict;
use warnings;

use Scalar::Util qw(weaken);

sub new {
  my ($proto,$config,$hub) = @_;
  my $class = ref($proto) || $proto;
  my $self = {
    tconf => $config,
    hub => $hub,
  };
  bless $self,$class;
  weaken($self->{'table'});
  $self->init();
  return $self;
}

sub init {}

sub hub { return $_[0]->{'hub'}; }
sub config { return $_[0]->{'tconf'}; }

sub children { return []; }
sub js_plugin { return undef; }
sub configure { $_[0]->{'config'} = $_[1]; }
sub requires { return []; }
sub position { return []; }
sub initial { return {}; }

sub js_config {
  my ($self) = @_;

  return {
    position => $self->{'config'}->{'position'} || $self->position,
  };
}

1;
