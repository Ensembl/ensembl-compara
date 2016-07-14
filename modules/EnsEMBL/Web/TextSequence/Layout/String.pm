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

package EnsEMBL::Web::TextSequence::Layout::String;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::TextSequence::Layout);

sub value_empty { return ''; }
sub value_pad { return ' ' x $_[1]; }
sub value_fmt { return sprintf($_[1],@{$_[2]}); }
sub value_cat { return join('',@{$_[1]}); }
sub value_length { return length $_[1]; }
sub value_append { ${$_[1]} .= join('',@{$_[2]}); }

1;
