=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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
use POSIX qw(floor ceil);
use List::Util qw(max min);

use Exporter qw(import);
our @EXPORT_OK = qw(mr_bump do_bump text_bounds bump bump_row);

# Fast bumping for new drawing code. This method just sets _bstart and
# _bend (the start and end co-ordinates for the purposes of bumping)
# according to the feature start and end and any label start and end.
# It then delegates to bumping to do_bump. If you want to set these
# keys yourself, to customise the bumping (ag GlpyhSet_simpler does)
# then feel free, and just call do_bump. For a description of the new
# bumping algorithm see do_bump.
# We deliberately compute label widths even if not displaying them.
# This helps when, eg, we will later bump labels elsewhere, eg in the
# gene renderer.
sub mr_bump {
  my ($object,$features,$show_label,$max,$strand,$moat) = @_;

  $moat ||= 0;
  my $pixperbp = $object->{'pix_per_bp'} || $object->scalex;
  foreach my $f (@$features) {
    my ($start,$end) = ($f->{'start'},$f->{'start'});
    $start = $f->{'start'};
    if($f->{'label'} && !$f->{'_lwidth'}) {
      my ($width,$height) = text_bounds($object, $f->{'label'});
      $f->{'_lheight'} = $height;
      $f->{'_lwidth'} = $width/$pixperbp;
    }
    if($show_label<2) { $end = $f->{'end'}; }
    if($show_label && $f->{'label'}) {
      $end = max($end,ceil($start+$f->{'_lwidth'}));
      my $overlap = $end-$max+1;
      if($overlap>0) {
        $start -= $overlap;
        $end -= $overlap;
      }
    }
    $f->{'_bstart'} = max(0,$start-$moat/$pixperbp);
    $f->{'_bend'} = min($end+$moat/$pixperbp,$max);
    if($strand and $f->{'strand'} and $strand != $f->{'strand'}) {
      $f->{'_bskip'} = 1;
    }
  }
  return do_bump($object, $features);
}

# Bump features according to their [_bstart,_bend], and set the row to a
# new key _bump in that method. On large regions (in bp terms) this can
# be orders of magnitude faster than the old algorithm.
#
# We can do this efficiently now, without tricks and big data structures
# because we have all features in-hand, and so can choose the order of
# applying them. Bumping amounts to an algorithm which attempts to add a
# range to a list of existing ranges (rows), adding it to the first with
# which there is no overlap. We sort the additions by start coordinate.
# For each row, we store the largest end co-ord on that row to-date.
# We add to the first row where our start is less than that row's end
# (and then set it to our end).
# If a row has an end greater than our start as we know it must have
# been set by a feature with a start less than ours (because of the
# order of addition), we know there is an overlap, and so this row is
# not available to us. Conversely, if our start is greater than the
# current end, we know that all features must be strictly to our left
# (also because of the order) and so we guarantee no overlap. Therefore
# this guarantees the minimum correct row.
sub do_bump {
  my ($object,$features) = @_;

  my (@bumps,@rows);
  foreach my $f (sort { $a->{'_bstart'} <=> $b->{'_bstart'} } @$features) {
    $f->{'_bstart'} = 0 if $f->{'_bstart'} < 0;
    next if $f->{'_bskip'};
    my $row = 0;
    while(($rows[$row]||=-1)>=$f->{'_bstart'}) { $row++; }
    $rows[$row] = $f->{'_bend'};
    $f->{'_bump'} = $row;
  }
  return scalar @rows;
}

sub text_bounds {
  my ($object,$text) = @_;

  my ($w,$h) = (0,0);
  foreach my $line (split("\n",$text)) {
    my $info;
    if($object->can('get_text_info')) {
      $info = $object->get_text_info($line);
    } else {
      my @props = $object->get_text_width(0,"$line ",'',%{$object->text_details});
      $info = { width  => $props[2],
                height => $props[3]+4 };
    }
    $w = max($w,$info->{'width'});
    $h += $info->{'height'};
  }
  return ($w,$h);
}


################ LEGACY BUMP METHODS - SHOULD BE DEPRECATED? #############################

## TODO Work out why the heck we have two very slightly different bump methods!

sub bump {
### Adapted from the original bumping code from GlyphSet.pm
  my ($tally, $start, $end, $truncate_if_outside, $key) = @_;
  $key         ||= '_bump';
  $start         = 1 if $start < 1;
  my $row_length = $tally->{$key}{'length'};

  return -1 if $end > $row_length && $truncate_if_outside; # used to not display partial text labels
  return -1 if $start > $row_length;

  $end   = $row_length if $end > $row_length;
  $start = floor($start);
  $end   = ceil($end);

  my $row     = 0;
  my $length  = $end > $start ? $end - $start : $start - $end;
  $length++;
  my $element = '0' x $row_length;

  substr($element, $start, $length) = '1' x $length;

  while ($row < $tally->{$key}{'rows'}) {
    if (!$tally->{$key}{'array'}[$row]) { # We have no entries in this row - so create a new row
      $tally->{$key}{'array'}[$row] = $element;
      return $row;
    }

    if (($tally->{$key}{'array'}[$row] & $element) == 0) { # We already have a row, but the element fits so include it
      $tally->{$key}{'array'}[$row] |= $element;
      return $row;
    }

    $row++; # Can't fit in on this row go to the next row..
  }

  return -1; # If we get to this point we can't draw the feature
}

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
