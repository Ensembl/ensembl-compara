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

sub change_CSS_colours {
  my $species_defs = shift;
  local $/ = undef;
  my %colours = %{$species_defs->ENSEMBL_STYLE||{}};
  foreach (keys %colours) {
    $colours{$_} =~ s/^([0-9A-F]{6})$/#$1/i;
  }
  my $css_directory = $species_defs->ENSEMBL_SERVERROOT.'/htdocs/components';
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
