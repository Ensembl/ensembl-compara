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
package Bio::Tools::Run::Search::wublastn;
use strict;
use Storable qw(dclone);

use vars qw( @ISA 
             $ALGORITHM $VERSION 
             $PARAMETER_OPTIONS 
             @PARAMETER_SENSITIVITIES
             $PROGRAM_NAME);

use Bio::Tools::Run::Search::WuBlast;

@ISA = qw( Bio::Tools::Run::Search::WuBlast );

BEGIN{
  $ALGORITHM     = 'BLASTN';
  $VERSION       = 'Unknown';
  $PROGRAM_NAME  = 'blastn';

  $PARAMETER_OPTIONS = dclone
    ( $Bio::Tools::Run::Search::WuBlast::PARAMETER_OPTIONS );

  @PARAMETER_SENSITIVITIES =
    ( @Bio::Tools::Run::Search::WuBlast::PARAMETER_SENSITIVITIES );

  delete( $PARAMETER_OPTIONS->{'-matrix'} ); # NA for blastn
  delete( $PARAMETER_OPTIONS->{'-T'} );      # NA for blastn

  # Turn off filtering for OLIGOs
  $PARAMETER_OPTIONS->{'-filter'}{'default_OLIGO'}  = 'none';

  $PARAMETER_OPTIONS->{'-M'} = # blastn only
    {
     default        => undef, #default: 5
     default_LOW    => 1,
     default_MEDIUM => 1,
     default_HIGH   => 1,
     default_EXACT  => 1,
     default_OLIGO  => 1,
     order          => 145,
     options        => [ undef, 1,2,3,4,5 ],
     description    => 'Match score',
    };

  $PARAMETER_OPTIONS->{'-N'} = # blastn only
    {
     default        => undef, #default: -4,
     default_LOW    => -3,
     default_MEDIUM => -1,
     default_HIGH   => -1,
     default_EXACT  => -3,
     default_OLIGO  => -3,
     order          => 146,
     options        => [ undef, -1,-2,-3,-4,-5 ],
     description    => 'Missmatch score',
    };

  # -W; Word size for seeding alignments
  $PARAMETER_OPTIONS->{'-W'}{'default_EXACT'}  = 15;
  $PARAMETER_OPTIONS->{'-W'}{'default_OLIGO'}  = 11;
  $PARAMETER_OPTIONS->{'-W'}{'default_LOW'}    = 15;
  $PARAMETER_OPTIONS->{'-W'}{'default_MEDIUM'} = 11;
  $PARAMETER_OPTIONS->{'-W'}{'default_HIGH'}   = 9;

  # -wink; Step-size for sliding-window used to seed alignments
  $PARAMETER_OPTIONS->{'-wink'}{'default_EXACT'} = 15;

  # -Q, Cost of first gap character
  $PARAMETER_OPTIONS->{'-Q'}{'default_EXACT'}  = 10;
  $PARAMETER_OPTIONS->{'-Q'}{'default_OLIGO'}  = 3;
  $PARAMETER_OPTIONS->{'-Q'}{'default_LOW'}    = 3;
  $PARAMETER_OPTIONS->{'-Q'}{'default_MEDIUM'} = 2;
  $PARAMETER_OPTIONS->{'-Q'}{'default_HIGH'}   = 2;

  # -R, Cost of second and remaining gap characters
  $PARAMETER_OPTIONS->{'-Q'}{'default_EXACT'}  = 10;
  $PARAMETER_OPTIONS->{'-R'}{'default_OLIGO'}  = 3;
  $PARAMETER_OPTIONS->{'-R'}{'default_LOW'}    = 3;
  $PARAMETER_OPTIONS->{'-R'}{'default_MEDIUM'} = 1;
  $PARAMETER_OPTIONS->{'-R'}{'default_HIGH'}   = 1;

  # -nogap; Turns off gapped alignments
  $PARAMETER_OPTIONS->{'-nogap'}{'default_EXACT'} = 1;

  # -X; Alignment extension cutoff
  $PARAMETER_OPTIONS->{'-X'}{'default_EXACT'} = 5;

  # -filter, Program used to filter query sequence
  $PARAMETER_OPTIONS->{'-filter'}{'default'} = 'dust';
  $PARAMETER_OPTIONS->{'-filter'}{'options'} = [ 'none','dust','seg' ];

}

#----------------------------------------------------------------------
sub program_name{ 
  my $self = shift;
  my $pname = $self->SUPER::program_name(@_);
  return defined( $pname ) ?  $pname : $PROGRAM_NAME;
}
sub algorithm   { return $ALGORITHM }
sub version     { return $VERSION }
sub parameter_options { return $PARAMETER_OPTIONS }

#----------------------------------------------------------------------
1;
