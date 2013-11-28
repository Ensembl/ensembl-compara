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
package Bio::Tools::Run::Search::wutblastx;
use strict;
use Storable qw(dclone);

use vars qw( @ISA 
	     $ALGORITHM $VERSION 
	     $PARAMETER_OPTIONS
	     $PROGRAM_NAME );

use Bio::Tools::Run::Search::WuBlast;

@ISA = qw( Bio::Tools::Run::Search::WuBlast );

BEGIN{

  $ALGORITHM     = 'TBLASTX';
  $VERSION       = '1.4.6';
  $PROGRAM_NAME  = 'tblastx';

  $PARAMETER_OPTIONS = dclone
    ( $Bio::Tools::Run::Search::WuBlast::PARAMETER_OPTIONS );

  delete $PARAMETER_OPTIONS->{'-RepeatMasker'};

  $PARAMETER_OPTIONS->{'-W'}{'default_LOW'}    = 4;
  $PARAMETER_OPTIONS->{'-W'}{'default_MEDIUM'} = 4;
  $PARAMETER_OPTIONS->{'-W'}{'default_HIGH'}   = 3;
  $PARAMETER_OPTIONS->{'-W'}{'default_EXACT'}  = 6;

  $PARAMETER_OPTIONS->{'-hitdist'}{'default_LOW'}  = 40;
  $PARAMETER_OPTIONS->{'-hitdist'}{'default_HIGH'} = 40;

  $PARAMETER_OPTIONS->{'-matrix'}{'default_LOW'}   ='BLOSUM62';
  $PARAMETER_OPTIONS->{'-matrix'}{'default_MEDIUM'}='BLOSUM62';
  $PARAMETER_OPTIONS->{'-matrix'}{'default_HIGH'}  ='BLOSUM62';
  $PARAMETER_OPTIONS->{'-matrix'}{'default_EXACT'} ='BLOSUM80';

  $PARAMETER_OPTIONS->{'-T'}{'default_LOW'}    = 20;
  $PARAMETER_OPTIONS->{'-T'}{'default_MEDIUM'} = 20;
  $PARAMETER_OPTIONS->{'-T'}{'default_HIGH'}   = 15;
  $PARAMETER_OPTIONS->{'-T'}{'default_EXACT'}  = 999;

  $PARAMETER_OPTIONS->{'-X'   }{'default_EXACT'}  = 10;
  $PARAMETER_OPTIONS->{'-nogap'}{'default_EXACT'}  = 1;

}

#----------------------------------------------------------------------
sub program_name{ 
  my $self = shift;
  my $pname = $self->SUPER::program_name(@_);
  return defined( $pname ) ?  $pname : $PROGRAM_NAME;
}
sub algorithm   { return $ALGORITHM }
sub version     { return $VERSION }
sub parameter_options{ return $PARAMETER_OPTIONS }
#----------------------------------------------------------------------
1;
