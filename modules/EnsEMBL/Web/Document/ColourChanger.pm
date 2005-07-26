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
sub change_Graphics_colours {
  my $species_defs = shift;
  my $colours = $species_defs->ENSEMBL_COLOURS;
  my $map0 = quotemeta(pack('H6','ffdf27')); my $col0 = pack( 'H6', $colours->{'background0'});
  my $map1 = quotemeta(pack('H6','ffffe7')); my $col1 = pack( 'H6', $colours->{'background1'});
  my $map2 = quotemeta(pack('H6','ffffdd')); my $col2 = pack( 'H6', $colours->{'background2'});
  my $map3 = quotemeta(pack('H6','ffffcc')); my $col3 = pack( 'H6', $colours->{'background3'});
  my $map4 = quotemeta(pack('H6','999900')); my $col4 = pack( 'H6', $colours->{'background4'});

  foreach my $dir (qw(buttons dd_menus) ) {
    my $D = "@{[$species_defs->ENSEMBL_SERVERROOT]}/htdocs/img/$dir";
    next unless opendir( DIR, "$D/templates" );
    foreach my $img_name ( readdir(DIR) ) {
      my $F = "$D/templates/$img_name";
      next unless -f $F;
      my $l = -s $F;
      next unless open I,$F;
      my $gif;
      read I,$gif,$l;
      close I;
      $gif =~s/$map1/$col1/;
      $gif =~s/$map2/$col2/;
      $gif =~s/$map3/$col3/;
      $gif =~s/$map4/$col4/;
      $gif =~s/$map0/$col0/;
      open( O, ">$D/$img_name" ) || next;
      binmode(O);
      print O $gif;
      close O;
    }
  }
}

sub change_CSS_colours {
  my $species_defs = shift;
  local $/ = undef;
  my $colours = $species_defs->ENSEMBL_COLOURS;
  my @files = ('js/zmenu.js', $species_defs->ENSEMBL_TMPL_CSS, $species_defs->ENSEMBL_CONTENT_CSS );
  foreach my $file ( @files ) {
    my $filename = "@{[$species_defs->ENSEMBL_SERVERROOT]}/htdocs/$file";
    my $TEMPLATE = '';
    if( open( I, "$filename-tmpl" ) ) {
      if( open( O, ">$filename" ) {
        $TEMPLATE = <I>;
        $TEMPLATE =~s/###(\w+)###/$colours->{$1}/eg;
        print O  $TEMPLATE;
        close O;
      }
      close I;
    }
  }
}

1;
