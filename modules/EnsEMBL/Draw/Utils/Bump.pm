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

package EnsEMBL::Draw::Utils::Bump;

###############################################################################
#
#   NAME:	    Bump.pm
#
#   DESCRIPTION:    Bumping code.  Pass in the start and end of the thing you
#		    want bumping, the length of the thing to bump against, and
#		    a reference to an array.  The array will be modified by
#		    this subroutine, to maintain persistence.
#
###############################################################################

use strict;
use Carp;
sub bump_row {
  my($start,$end,$bit_length,$bit_array,$max_row)=@_;
  $max_row = 1e9 unless defined $max_row;
  my $row=0;
  my $len=$end-$start+1;

  if( $len <= 0 || $bit_length <= 0 ) {
    carp("We've got a bad length of $len or $bit_length from $start-$end in Bump. Probably you haven't flipped on a strand");
  }

  my $element='0' x $bit_length;
   
  substr($element, $start,$len)='1' x $len;
  
  LOOP:{
    if($$bit_array[$row]) {
      if( ($bit_array->[$row] & $element)==0 ) {
        $bit_array->[$row]=($bit_array->[$row] | $element);
      } else {
        $row++;
        return $max_row + 10 if $row > $max_row;
        redo LOOP;
      } 
	} else {
      $$bit_array[$row]=$element;
    }
  }
  return $row;
}

1;
