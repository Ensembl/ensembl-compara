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
