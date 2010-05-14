#!/usr/local/bin/perl
###############################################################################
#   
#   Name:        EnsEMBL::Web::Tools::DHTMLmerge
#    
#   Description: Populates templates for static content.
#                Run at server startup
#
###############################################################################

package EnsEMBL::Web::Tools::DHTMLmerge;

use strict;

use Digest::MD5 qw(md5_hex);
use CSS::Minifier;
use JavaScript::Minifier;

sub merge_all {
  my ($species_defs) = @_;
  
  my $css_file = merge($species_defs, 'css');
  my $js_file  = merge($species_defs, 'js');
  
  $species_defs->{'_storage'}{'ENSEMBL_JSCSS_TYPE'} = 'minified';
  $species_defs->{'_storage'}{'ENSEMBL_JS_NAME'}    = $js_file;
  $species_defs->{'_storage'}{'ENSEMBL_CSS_NAME'}   = $css_file;
  
  $species_defs->store;
}

sub merge {
  my ($species_defs, $type) = @_;
  
  my $contents;
  my $jquery;
  
  foreach my $root (reverse @{$species_defs->ENSEMBL_HTDOCS_DIRS||[]}) {
    next if $root =~ /biomart/; # Not part of Ensembl template system
    
    my $dir = "$root/components";
    
    if (-e $dir && -d $dir) {
      opendir DH, $dir;
      my @T = readdir DH;
      my @files = sort grep { /^\d/ && -f "$dir/$_" && /\.$type$/ } @T;
      closedir DH;
      
      foreach my $fn (@files) {      
        open I, "$dir/$fn";
        local $/ = undef;
        my $file_contents = <I>;
        close I;
        
        if ($fn =~ /jquery\.js/) {
          $jquery = $file_contents;
        } else {
          $contents .= $file_contents;
        }       
      }
    }
  }
  
  # Convert style placeholders to actual colours
  my %colours = %{$species_defs->ENSEMBL_STYLE||{}};
  
  # Add sequence markup colours to ENSEMBL_STYLE - they are used in CSS. This smells a lot like a hack.
  my $sequence_markup = $species_defs->colour('sequence_markup') || {};
  my %styles = map { $_ => $sequence_markup->{$_}->{'default'} } keys %$sequence_markup;
  
  %colours = (%colours, %styles);
  $colours{$_} =~ s/^([0-9A-F]{6})$/#$1/i for keys %colours;
  
  $contents =~ s/\[\[(\w+)\]\]/$colours{$1}||"\/* ARG MISSING DEFINITION $1 *\/"/eg; 
  
  my $root_dir        = $species_defs->ENSEMBL_SERVERROOT;
  my $compression_dir = "$root_dir/utils/compression/";
  my $filename        = md5_hex("$jquery$contents");
  my $minified        = "$root_dir/htdocs/minified/$filename.$type";
  my $tmp             = "$minified.tmp";
  
  if (!-e $minified) {
    open  O, ">$tmp" or die "can't open $tmp for writing";    
    
    if ($type eq 'js') {
      print  O $jquery;
      printf O '(function($,window,document,undefined){%s})(jQuery,this,document)', $contents; # wrap javascript for extra compression
    } else {
      print O $contents;
    }
    
    close O;
   
    if ($type eq 'js') {
      system $species_defs->ENSEMBL_JAVA, '-jar', "$compression_dir/compiler.jar", '--js', $tmp, '--js_output_file', $minified, '--compilation_level', 'SIMPLE_OPTIMIZATIONS', '--warning_level', 'QUIET';
    } else {
      system $species_defs->ENSEMBL_JAVA, '-jar', "$compression_dir/yuicompressor-2.4.2.jar", '--type', 'css', '-o', $minified, $tmp;
    }
    
    unlink $tmp;
    
    if (!-e $minified) {
      open  O, ">$minified" or die "can't open $minified for writing";
      print O $type eq 'css' ? CSS::Minifier::minify(input => $contents) : JavaScript::Minifier::minify(input => "$jquery$contents");
      close O;
    }
  }
  
  return $filename;
}

1;
