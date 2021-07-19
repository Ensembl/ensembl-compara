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

use strict;
use warnings;

package EnsEMBL::Web::NewTable::Plugins::Core;
use parent qw(EnsEMBL::Web::NewTable::Plugin);

sub children { return [qw(Tabular Paragraph Loading Types Ancient ServerEnum Config Unshowable)]; }
sub requires { return children(); }

package EnsEMBL::Web::NewTable::Plugins::Tabular;
use parent qw(EnsEMBL::Web::NewTable::Plugin);

sub js_plugin { return "new_table_tabular"; }

package EnsEMBL::Web::NewTable::Plugins::Paragraph;
use parent qw(EnsEMBL::Web::NewTable::Plugin);

sub js_plugin { return "new_table_paragraph"; }

package EnsEMBL::Web::NewTable::Plugins::Loading;
use parent qw(EnsEMBL::Web::NewTable::Plugin);

sub js_plugin { return "new_table_loading"; }
sub position { return [qw(top-middle)]; }

package EnsEMBL::Web::NewTable::Plugins::Types;
use parent qw(EnsEMBL::Web::NewTable::Plugin);

sub js_plugin { return "newtable_types"; }

package EnsEMBL::Web::NewTable::Plugins::Ancient;
use parent qw(EnsEMBL::Web::NewTable::Plugin);

sub js_plugin { return "newtable_ancient"; }

package EnsEMBL::Web::NewTable::Plugins::Config;
use parent qw(EnsEMBL::Web::NewTable::Plugin);

sub js_plugin { return "new_table_config"; }

package EnsEMBL::Web::NewTable::Plugins::Unshowable;
use parent qw(EnsEMBL::Web::NewTable::Plugin);

sub js_plugin { return "new_table_unshowable"; }

1;
