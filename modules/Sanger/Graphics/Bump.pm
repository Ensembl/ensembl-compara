package Sanger::Graphics::Bump;
###############################################################################
#
#   NAME:	    Bump.pm
#
#   DESCRIPTION:    Bumping code.  Pass in the start and end of the thing you
#		    want bumping, the length of the thing to bump against, and
#		    a reference to an array.  The array will be modified by
#		    this subroutine, to maintain persistence.
#
#   HISTORY:	    2001-01-05	jws	original version
#
###############################################################################

use strict;
use Carp;
sub bump_row {
    my($start,$end,$bit_length,$bit_array)=@_;
    my $row=0;
    my $len=$end-$start+1;

    if( $len <= 0 || $bit_length <= 0 ) {
       carp("We've got a bad length of $len or $bit_length from $start-$end in Bump. Probably you haven't flipped on a strand");
    }

    my $element='0' x $bit_length;
    
    substr($element, $start,$len)='1' x $len;
    
    LOOP:{
        if($$bit_array[$row]){
            if (($bit_array->[$row] & $element)==0){
                $bit_array->[$row]=($bit_array->[$row] | $element);
            } else {
                $row++;
                redo LOOP;
            }
	} else{
            $$bit_array[$row]=$element;
        }
    }
    return $row;
}

1;
