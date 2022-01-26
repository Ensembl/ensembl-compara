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

package EnsEMBL::Web::Tools::RobotsTxt;

use strict;
use warnings;

use EnsEMBL::Web::Exceptions;
use EnsEMBL::Web::Utils::FileHandler qw(file_put_contents);

sub create {
  ## Creates the robots.txt file and places it in the htdocs folder (unless an alternative directory is configured)
  ## @return none
  my $species   = shift;
  my $sd        = shift;
  my $root      = $sd->ENSEMBL_ROBOTS_TXT_DIR || $sd->ENSEMBL_WEBROOT.'/htdocs';
  my $map_dir   = $sd->GOOGLE_SITEMAPS_PATH || $sd->ENSEMBL_WEBROOT.'/htdocs/sitemaps';
  my @lines;

  if ($SiteDefs::ENSEMBL_CUSTOM_ROBOTS_TXT) {
    warn _box('Not creating robots.txt (a custom one in use)');
    return;
  }

  warn _box(sprintf 'Placing robots.txt into %s (Searchable: %s)', $root, $sd->ENSEMBL_EXTERNAL_SEARCHABLE ? 'Yes' : 'No');

  if ($sd->ENSEMBL_EXTERNAL_SEARCHABLE) {

    push @lines, _lines("User-agent", "*");
    push @lines, _lines("Disallow", qw(
  				 /Multi/  /biomart/  /Account/ */DataExport/ */ImageExport/ 
  				 */Ajax/  */Config/  */Export/  */Experiment/ */Experiment*
  				 */Family/ */ImageExport */Location/  */LRG/  */Marker/ 
           */Phenotype/ */Regulation/  */Search/ */Share */StructuralVariation/
  				 */UserConfig/  */UserData/  */Variation/
  			      ));
  
    #old views
    push @lines, _lines("Disallow", qw(*/*view));
  
    #other misc views google bot hits
    push @lines, _lines("Disallow", qw(/*/Psychic));
  
    foreach my $row (('A'..'Z','a'..'z')){
      next if lc $row eq 's';
      push @lines, _lines("Disallow", "*/Gene/$row*", "*/Transcript/$row*");
    }
  
    # a bunch of others that are being bypassed
    foreach my $row (qw(Species Secondary Similarity Supporting Sequence Structural Splice)) {
      push @lines, _lines("Disallow", "*/Gene/$row*", "*/Transcript/$row*");
    }
  
    # links from ChEMBL
    push @lines, _lines("Disallow", "/Gene/Summary");
    push @lines, _lines("Disallow", "/Transcript/Summary");
  
    # Doxygen
    push @lines, _lines("Disallow", "/info/docs/Doxygen");
  
    if (-e "$map_dir/index.xml") {
      # If we have a sitemap let google know about it.
      warn _box("Creating robots.txt for google sitemap");
      ## Set appropriate domain for links
      my $server = $sd->ENSEMBL_SERVERNAME;
      my $domain;
      if ($sd->GENOMIC_UNIT) {
        $domain = sprintf 'http://%s.ensembl.org', $sd->GENOMIC_UNIT;
      }
      elsif ($server =~ m#/m\.ensembl|mtest#) {
        $domain = 'http://m.ensembl.org';
      }
      else {
        $domain = 'http://www.ensembl.org';
      }
      push @lines, _lines("Sitemap", sprintf '%s/sitemaps/index.xml', $domain);
    }

    ## SPECIFIC CRAWLERS

    push @lines, _lines("User-agent", "W3C-checklink");
    push @lines, _lines("Allow", "/info");
  
    # Limit Blekkobot's crawl rate to only one page every 20 seconds.
    push @lines, _lines("User-agent", "Blekkobot");
    push @lines, _lines("Crawl-delay", "20");
  
    # stop AhrefsBot indexing us (https://ahrefs.com/robot/)
    push @lines, _lines("User-agent", "AhrefsBot");
    push @lines, _lines("Disallow", "/");
  
  } else {
    push @lines, _lines("User-agent", "*");
    push @lines, _lines("Disallow", "/");
  }

  $lines[0] =~ s/^\n//;

  try {
    file_put_contents("$root/robots.txt", @lines);
  } catch {
    warn _box("Could not create robots.txt due to the following error:\n$_");
  };
}

sub _lines { # utility
  my $type = shift;
  return map { sprintf "%s%s: %s\n", $type eq 'User-agent' ? "\n" : '', $type, $_ } @_;
}

sub _box {
  my $text  = shift;
  my @lines = split "\n", $text;
  return join("\n", '-' x length $lines[0], $text, '-' x length $lines[-1], '');
}

1;
