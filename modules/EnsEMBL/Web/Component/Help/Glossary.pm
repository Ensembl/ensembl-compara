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

package EnsEMBL::Web::Component::Help::Glossary;

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Hub;
use EnsEMBL::Web::DBSQL::WebsiteAdaptor;

use base qw(EnsEMBL::Web::Component::Help);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
  $self->configurable( 0 );
}

sub content {
  my $self    = shift;
  my $hub     = $self->hub || EnsEMBL::Web::Hub->new;
  my $adaptor = EnsEMBL::Web::DBSQL::WebsiteAdaptor->new($hub);
  my $table   = $self->new_twocol({'striped' => 1});
  my $words   = ($hub->param('id') ? $adaptor->fetch_help_by_ids([ $hub->param('id') ]) : $adaptor->fetch_glossary) || [];

  $table->add_row(
    $_->{'word'} . ( $_->{'expanded'} ? " ($_->{'expanded'})" : '' ),
    $_->{'meaning'}
  ) for @$words;

  return sprintf '<h2>Glossary</h2>%s', $table->render;
}

1;
