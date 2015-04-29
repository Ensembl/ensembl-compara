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

package EnsEMBL::Web::Document::Element::Copyright;

### Copyright notice for footer (basic version with no logos)

use strict;

use base qw(EnsEMBL::Web::Document::Element);

sub new {
  return shift->SUPER::new({
    %{$_[0]},
    sitename => '?'
  });
}

sub sitename :lvalue { $_[0]{'sitename'}; }

sub content {
  my @time = localtime;
  my $year = @time[5] + 1900;
  
  return qq{
    <div class="column-two left">
      <p>&copy; $year <span class="print_hide"><a href="http://www.sanger.ac.uk/" class="nowrap">WTSI</a> / 
        <a href="http://www.ebi.ac.uk/" style="white-space:nowrap">EBI</a></span>
        <span class="screen_hide_inline">WTSI / EBI</span>.
        (<a href="http://www.ensembl.org/info/about/legal/privacy.html">Privacy policy</a>)
      </p>
    </div>
  };
}

sub init {
  $_[0]->sitename = $_[0]->species_defs->ENSEMBL_SITETYPE;
}

1;
