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

package EnsEMBL::Web::BlastView::MetaBlock;

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::BlastView::Meta;

use vars qw(@ISA);
@ISA = qw(EnsEMBL::Web::BlastView::Meta);

sub _object_template{ 
  return 
    (
     -name         => '', # ID for this object
     -parent       => '', # ID of parent object (i.e. stage name)
     -forms        => [], # List of child objects (i.e. forms)
     
     -label        => '',
     -focus        => ['__ALL__'], # DEPRECATED
     -outtype      => ['__ALL__'], # DEPRECATED

     -available      => ['1'], # Availability. Array exp's ANDed
     -error          => [], # Error detection code_ref/regexp/value
     -cgi_processing => [], # 'cgi value' processing code references 

     -jscript        => '', # Javascript code to add to HTML header
     -jscript_onload => '', # Javascript function to add to <BODY> tag

     -form_list    => [], # Deprecated
    );
}

#----------------------------------------------------------------------
1;
