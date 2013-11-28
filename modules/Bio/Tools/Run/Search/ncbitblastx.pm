=head1 LICENSE

Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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


# Let the code begin...
package Bio::Tools::Run::Search::ncbitblastx;
use strict;
use Storable qw(dclone);

use vars qw( @ISA 
	     $ALGORITHM 
	     $VERSION 
	     $PARAMETER_OPTIONS );

use Bio::Tools::Run::Search::NCBIBlast;

@ISA = qw( Bio::Tools::Run::Search::NCBIBlast );

BEGIN{

  $ALGORITHM     = 'TBLASTX';
  $VERSION       = 'Unknown';

  $PARAMETER_OPTIONS = dclone
    ( $Bio::Tools::Run::Search::NCBIBlast::PARAMETER_OPTIONS );

}

#----------------------------------------------------------------------
sub algorithm   { return $ALGORITHM }
sub version     { return $VERSION }
sub parameter_options { return $PARAMETER_OPTIONS }

#----------------------------------------------------------------------
1;
