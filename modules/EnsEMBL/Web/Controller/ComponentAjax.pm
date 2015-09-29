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

package EnsEMBL::Web::Controller::ComponentAjax;

use strict;

use Apache2::RequestUtil;
use HTML::Entities  qw(decode_entities);
use JSON            qw(from_json);
use URI::Escape     qw(uri_unescape);

use EnsEMBL::Web::ViewConfig::Regulation::Page;
use EnsEMBL::Web::DBSQL::WebsiteAdaptor;
use EnsEMBL::Web::Hub;
use EnsEMBL::Web::NewTable::Callback;

use base qw(EnsEMBL::Web::Controller::Component);

sub render_page {
  my ($self) = @_;

  my $func = $self->hub->param('source');
  $func =~ s/\W//g;
  $func = "ajax_$func";
  warn "func=$func\n";
  my $module_name = $self->hub->function;
  my $type = $self->hub->type;
  my $pkg = "EnsEMBL::Web::Component::${type}::${module_name}";
  $self->dynamic_use($pkg);
  my $renderer = undef;
  my $component = $pkg->new($self->hub,$self->builder,$renderer);
  $self->$func($component) if $self->can($func);
}

sub ajax_enstab {
  my ($self,$component) = @_;

  my $hub = $self->hub;
  my $data;
  eval {
    my $callback = EnsEMBL::Web::NewTable::Callback->new($hub,$component);
    my $out = $callback->go();
    $out = $self->jsonify($out) if ref($out);
    print $out;
  };
  if($@) {
    warn $@;
    print $self->jsonify({ failed => $@ });
  }
}

1;
