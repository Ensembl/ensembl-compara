# $Id$

package EnsEMBL::Web::Controller::AltPage;

### Alternative dynamic page with fluid layout

use strict;

use base qw(EnsEMBL::Web::Controller::Page);
 
sub page_type   { return 'Fluid'; }

1;
