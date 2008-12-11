#!/usr/local/bin/perl
###############################################################################
#   
#   Name:           EnsEMBL::HTML::StaticTemplates.pm
#   
#   Description:    Populates templates for static content.
#                   Run at server startup
#
###############################################################################

package EnsEMBL::Web::Document::DHTMLmerge;
use strict;
use warnings;
use File::Path;
use CSS::Minifier;
use JavaScript::Minifier;
use Digest::MD5 qw(md5_hex);
use Pack;

no warnings "uninitialized";

our $PERFORM_PACK = 0;

sub merge_all {
  my( $ini_file, $species_defs ) = @_;
  my $current_files = {'type'=>'minified','css'=>undef,'js'=>undef};
  if( -e $ini_file && open I, $ini_file ) {
    while(<I>) {
      $current_files->{$1}=$2 if /^(\w+)\s*=\s*(\S+)/;
    }
    close I;
  }
  my $css_update = merge( $species_defs, 'css', $current_files->{'css'} );
  my $js_update  = merge( $species_defs, 'js',  $current_files->{'js'}  );
  if( $css_update || $js_update ) {
    $current_files->{'css'} = $css_update ? $css_update : $current_files->{'css'};
    $current_files->{'js'}  = $js_update  ? $js_update  : $current_files->{'js'};
    open O, ">$ini_file";
    printf O "type = %s\ncss = %s\njs = %s\n",
      $current_files->{'type'}, $current_files->{'css'}, $current_files->{'js'};
    close O;
    $species_defs->{'_storage'}{'ENSEMBL_JSCSS_TYPE'} = $current_files->{'type'};
    $species_defs->{'_storage'}{'ENSEMBL_JS_NAME'}    = $current_files->{'js'};
    $species_defs->{'_storage'}{'ENSEMBL_CSS_NAME'}   = $current_files->{'css'};
    $species_defs->store(); 
  }
}

sub merge {
  my( $species_defs, $type, $current_file ) = @_;
  my %contents = ();
  my $first_root = ${SiteDefs::ENSEMBL_SERVERROOT}.'/htdocs/';
  foreach my $root ( reverse @SiteDefs::ENSEMBL_HTDOCS_DIRS ) {
    next if $root =~ /biomart/; ## Not part of Ensembl template system!
    my $dir = "$root/components";
    if( -e $dir && -d $dir ) {
      opendir DH, $dir;
      my @T = readdir( DH );
      my @files = sort grep { /^\d/ && -f "$dir/$_" && /\.$type$/ } @T;
      closedir DH;
      foreach my $fn (@files) {
        my($K,$V) = split /-/, $fn;
        open I, "$dir/$fn";
        local $/ = undef;
        my $CONTENTS = <I>;
        close I;
			  (	my $dir2 = $dir) =~ s/wwwmart/www/;
        $contents{$K} .= "
/***********************************************************************
 $dir2/$fn
***********************************************************************/

$CONTENTS

";
      }
    }
  }
  my $NEW_CONTENTS = '';
  foreach ( sort keys %contents ) {
    $NEW_CONTENTS .= $contents{$_};
  }

  ## Convert style placeholders to actual colours
  my %colours = %{$species_defs->ENSEMBL_STYLE||{}};
  foreach (keys %colours) {
    $colours{$_} =~ s/^([0-9A-F]{6})$/#$1/i;
  }
  $NEW_CONTENTS =~ s/\[\[(\w+)\]\]/$colours{$1}||"\/* ARG MISSING DEFINITION $1 *\/"/eg; 

  if( $current_file ) {
    if (open I, "$first_root/merged/$current_file.$type") {
      local $/ = undef;
      my $CONTENTS = <I>;
      close I;
      return undef if $CONTENTS eq $NEW_CONTENTS;
    }
  }
  my $filename = md5_hex( $NEW_CONTENTS );
  my $fn = "$first_root/merged/$filename.$type";
  
  open O, ">$fn" or die "can't open $fn for writing";
  print O $NEW_CONTENTS;
  close O;
  my $minified = "$first_root/minified/$filename.$type";
  my $temp;
  if( open O, ">$minified" ) {
    $temp = $type eq 'css' ?
      CSS::Minifier::minify(input => $NEW_CONTENTS ) :
      JavaScript::Minifier::minify( input => $NEW_CONTENTS );
    print O $temp;
    close O;
  } else {
    $minified = '';
  }
  return $filename unless $PERFORM_PACK;
  my $packed0 = "$first_root/packed.0/$filename.$type";
  if( open O, ">$packed0" ) {
    $temp = Pack::pack($NEW_CONTENTS,0,1,1) if $type eq 'js';
    print O $temp;
    close O;
  } else {
    $packed0 = '';
  }
  my $packed = "$first_root/packed/$filename.$type";
  if( open O, ">$packed" ) {
    $temp = Pack::pack($NEW_CONTENTS,62,1,1) if $type eq 'js';
    print O $temp;
    close O;
  } else {
    $packed = '';
  }
  return $filename;
}

1;
