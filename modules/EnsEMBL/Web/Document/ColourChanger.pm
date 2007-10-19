#!/usr/local/bin/perl
###############################################################################
#   
#   Name:           EnsEMBL::HTML::StaticTemplates.pm
#   
#   Description:    Populates templates for static content.
#                   Run at server startup
#
###############################################################################

package EnsEMBL::Web::Document::ColourChanger;
use strict;
use warnings;
no warnings "uninitialized";

#----------------------------------------------------------------------
sub change_ddmenu_colours {
  my $species_defs = shift;
  my $colours = $species_defs->ENSEMBL_STYLE;
  my $img_directory = $species_defs->ENSEMBL_SERVERROOT.'/htdocs/img';
  my %colours = qw(170 BACKGROUND1 187 BACKGROUND2 204 BACKGROUND3 221 BACKGROUND4 238 BACKGROUND5);
  my $replace = {map { $_ => join( '', map { chr($_) } hex2rgb( $colours->{$colours{$_}} ) ) } keys %colours};
  if( opendir DH, "$img_directory/templates" ) {
    while( my $file = readdir DH ) {
      next if $file =~ /zoom\d\.gif/;
      next unless $file =~ /\.gif/;
      local $/ = undef;
      open I, "$img_directory/templates/$file";
      my $X = <I>;
      close I;
      my $flags = ord(substr($X,10,1));
      next unless $flags & 128; # No global colourmap arg!!
      my $colourcount = 2<<($flags&7);
      foreach my $N ( 1..$colourcount ) {
        my $index = $N*3+10;
        my $COL = ord(substr($X,$index,1));
        my $NEWCOL = $replace->{$COL};
        substr($X,$index,3) = $NEWCOL if $NEWCOL;
      }
      my $dir = $file =~ /^y/ ? 'dd_menus/' : '';
      if( open O, ">$img_directory/$dir$file" ) {
        print O $X;
        close O;
      }
    }
  }
} 

sub hex2rgb {
  my $hex = shift;
  my( $r, $g, $b ) = $hex =~ /(..)(..)(..)/;
  if( defined($r) ) {
    return( hex($r),hex($g),hex($b) );
  }
}

sub change_zoom_colours {
  my $species_defs = shift;
  my $colours = $species_defs->ENSEMBL_STYLE;
  my $img_directory = $species_defs->ENSEMBL_SERVERROOT.'/htdocs/img';
  my @C = hex2rgb( $colours->{'HEADING'} );
  my @O = hex2rgb( $colours->{'SPECIESNAME'} );
  my @B = hex2rgb( $colours->{'BACKGROUND5'} );
  foreach my $i (1..8) {
    local $/ = undef;
    open I, "$img_directory/templates/zoom$i.gif" || next;
    my $Y = my $X = <I>;
    close I;
    my $flags = ord(substr($X,10,1));
    next unless $flags & 128; # No global colourmap arg!!
    my $colourcount = 2<<($flags&7);
    my $left  = 80;
    my $right = 255-$left;
    foreach my $N ( 1..$colourcount ) {
      my $index = $N*3+10;
      my $COL = (ord(substr($X,$index,1)) + ord(substr($X,$index+1,1)) + ord(substr($X,$index+2,1)))/3;
      foreach my $P ( 0..2 ) {
        my $N_COL = $COL < $left ? 
          $COL * $C[$P] / $left :
          $C[$P] + ($COL-$left)/$right * ($B[$P]-$C[$P]);
        substr($X,$index+$P,1) = chr($N_COL);
      }
    }
    if( open O, ">$img_directory/buttons/zoom$i.gif" ) {
      print O $X;
      close O;
    }
    foreach my $N ( 1..$colourcount ) {
      my $index = $N*3+10;
      my $COL = (ord(substr($Y,$index,1)) + ord(substr($Y,$index+1,1)) + ord(substr($Y,$index+2,1)))/3;
      foreach my $P ( 0..2 ) {
        my $N_COL = $COL < $left ?
          $COL * $C[$P] / $left :
          $O[$P] + ($COL-$left)/$right * ($B[$P]-$O[$P]);
        substr($Y,$index+$P,1) = chr($N_COL);
      }
    }
    if( open O, ">$img_directory/buttons/zoom${i}on.gif" ) {
      print O $Y;
      close O;
    }
    close I;
  }

}

sub change_CSS_colours {
  my $species_defs = shift;
  local $/ = undef;
  my %colours = %{$species_defs->ENSEMBL_STYLE||{}};
  foreach (keys %colours) {
    $colours{$_} =~ s/^([0-9A-F]{6})$/#$1/i;
  }
  my $css_directory = $species_defs->ENSEMBL_SERVERROOT.'/htdocs/css';
  if( opendir DH, $css_directory ) {
    while ( my $file = readdir DH ) {
      if( $file =~ /^(.*)-tmpl$/ ) {
        open I, "$css_directory/$file" || next;
        if( open O, ">$css_directory/$1" ) {
          local( $/ ) = undef;
          my $T = <I>;
          $T =~ s/\[\[(\w+)\]\]/$colours{$1}||"\/* ARG MISSING DEFINITION $1 *\/"/eg;
          print O $T;
          close O;
        }
        close I;
      }
    }
  }
  chdir $css_directory;
}

1;
