=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

#----------------------------------------------------------------------
#
# TODO docs
#
#----------------------------------------------------------------------

package EnsEMBL::Web::BlastView::MetaStage;

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::BlastView::Meta;

use vars qw(@ISA);
@ISA = qw(EnsEMBL::Web::BlastView::Meta);

sub _object_template{ 
  return 
    (
     -name             => '', # ID for this object
     -parent           => '', # ID of parent object (Stage has none!)
     -blocks           => [], # List of child objects (i.e. blocks)

     -available        => [], # Availability. Array exp's ANDed
     -error            => [], # Error detection code_ref/regexp/value
     -cgi_processing   => [], # 'cgi value' processing code references 
     -javascript_files => [], # Javascript files to be included in the page
     -javascript_onload=> [], # Javascript functions to pre-load

     -number_summary => '%s', # Used for the 'xx Entries' label in the summary
     -page_header   => {title=>'',text=>[]},    # Para struct for head(TODO: make this an object)
     -page_footer   => {title=>'',text=>[]},    # Para struct for foot(TODO: make this an object)

     -block_list    => [], # Deprecated
    );
}

#----------------------------------------------------------------------
1;
