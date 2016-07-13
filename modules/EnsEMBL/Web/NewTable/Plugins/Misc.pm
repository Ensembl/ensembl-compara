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

use strict;
use warnings;

package EnsEMBL::Web::NewTable::Plugins::Misc;
use parent qw(EnsEMBL::Web::NewTable::Plugin);

sub children { return [qw(Export Search Columns Styles HelpTips)]; }
sub requires { return [qw(Export Search Columns)]; }

package EnsEMBL::Web::NewTable::Plugins::Export;
use parent qw(EnsEMBL::Web::NewTable::Plugin);

sub js_plugin { return "newtable_export"; }
sub position { return [qw(top-right top)]; }

package EnsEMBL::Web::NewTable::Plugins::Search;
use parent qw(EnsEMBL::Web::NewTable::Plugin);

sub js_plugin { return "new_table_search"; }
sub position { return [qw(top-right)]; }

package EnsEMBL::Web::NewTable::Plugins::Columns;
use parent qw(EnsEMBL::Web::NewTable::Plugin);

sub js_plugin { return "new_table_columns"; }
sub position { return [qw(top-middle)]; }

package EnsEMBL::Web::NewTable::Plugins::Styles;
use parent qw(EnsEMBL::Web::NewTable::Plugin);

sub js_plugin { return "new_table_style"; }
sub js_config {
  return {
    styles => [["tabular","Tabular"],["paragraph","Paragraph"]]
  };
}

package EnsEMBL::Web::NewTable::Plugins::HelpTips;
use parent qw(EnsEMBL::Web::NewTable::Plugin);

sub js_plugin { return "newtable_helptip"; }

1;
