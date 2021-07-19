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

package EnsEMBL::Web::Command::Help::DoSearch;

# Searches the help_record table in the ensembl_website database 

use strict;
use warnings;

use EnsEMBL::Web::DBSQL::WebsiteAdaptor;

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self = shift;
  my $hub = $self->hub;

  my $adaptor = EnsEMBL::Web::DBSQL::WebsiteAdaptor->new($hub);
  my $ids = $adaptor->search_help($hub->param('string'));

  my $new_param = {
    'result' => $ids,
  };
  if ($hub->param('hilite')) {
    $new_param->{'hilite'} = $hub->param('hilite');
    $new_param->{'string'} = $hub->param('string');
  }

  $self->ajax_redirect('/Help/Results', $new_param);
}

1;
