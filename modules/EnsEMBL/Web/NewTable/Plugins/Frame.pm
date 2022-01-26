=head1 LICENSE

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

use strict;
use warnings;

package EnsEMBL::Web::NewTable::Plugins::Frame;
use parent qw(EnsEMBL::Web::NewTable::Plugin);

sub children { return [qw(FrameDefault)]; }
sub requires { return children(); }

package EnsEMBL::Web::NewTable::Plugins::FrameDefault;
use parent qw(EnsEMBL::Web::NewTable::Plugin);

sub js_plugin { return "newtable_frame_default"; }

1;
