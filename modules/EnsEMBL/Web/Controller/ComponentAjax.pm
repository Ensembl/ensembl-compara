=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Controller::ComponentAjax;

use strict;
use warnings;

use JSON;

use EnsEMBL::Web::Exceptions;
use EnsEMBL::Web::NewTable::Callback;
use EnsEMBL::Web::Utils::DynamicLoader qw(dynamic_require);

use parent qw(EnsEMBL::Web::Controller::Component);

sub render_page {
  ## @override
  my $self  = shift;
  my $func  = $self->hub->param('source') || '';
     $func  =~ s/\W//g;
     $func  = "ajax_$func";

  my $res;

  try {
    $res = $self->$func(dynamic_require($self->component)->new($self->hub, $self->builder, undef)) if $self->can($func);
  } catch {
    $res = { 'failed' => $_->message };
  };

  printf to_json($res || {});
}

sub ajax_enstab {
  my ($self, $component) = @_;

  my $callback  = EnsEMBL::Web::NewTable::Callback->new($self->hub, $component);
  my $out       = $callback->go();

  return $out if ref $out;
}

1;
