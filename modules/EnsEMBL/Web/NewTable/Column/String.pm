=head1 sLICENSE

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

package EnsEMBL::Web::NewTable::Column::String;

use strict;
use warnings;
use parent qw(EnsEMBL::Web::NewTable::Column);

sub js_type { return 'string'; }
sub js_range { return 'class'; }

sub null { return $_[1] !~ /\S/; }
sub cmp { return (lc $_[1] cmp lc $_[2])*$_[3]; }
sub has_value { return $_[1]->{$_[2]} = 1; }
sub range { return [sort keys %{$_[1]}]; }
sub split { return $_[1]?[$_[1]]:[]; }

1;
