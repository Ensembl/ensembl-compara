
# Let the code begin...
package Bio::Tools::Run::Search::paracelblastx;
use strict;
use Storable qw(dclone);

use vars qw( @ISA 
	     $ALGORITHM 
	     $VERSION 
	     $PARAMETER_OPTIONS );

use Bio::Tools::Run::Search::ParacelBlast;

@ISA = qw( Bio::Tools::Run::Search::ParacelBlast );

BEGIN{

  $ALGORITHM     = 'BLASTX';
  $VERSION       = 'Unknown';

  $PARAMETER_OPTIONS = dclone
    ( $Bio::Tools::Run::Search::ParacelBlast::PARAMETER_OPTIONS );

}

#----------------------------------------------------------------------
sub algorithm   { return $ALGORITHM }
sub version     { return $VERSION }
sub parameter_options { return $PARAMETER_OPTIONS }

#----------------------------------------------------------------------
1;
