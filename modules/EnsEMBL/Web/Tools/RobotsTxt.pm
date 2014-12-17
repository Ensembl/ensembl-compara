=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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
  ## Creates the robots.txt file and places it in the htdocs folder
  ## @return none
  my $species = shift;
  my $sd      = shift;
  my $root    = $sd->ENSEMBL_WEBROOT . '/htdocs';
  my @lines;

  warn _box("Placing robots.txt into $root");

  if ($sd->ENSEMBL_EXTERNAL_SEARCHABLE) {

    push @lines, _lines("User-agent", "*");
    push @lines, _lines("Disallow", qw(
  				 /Multi/  /biomart/  /Account/  /ExternalData/  /UserAnnotation/
  				 */Ajax/  */Config/  */Export/  */Experiment/ */Experiment*
  				 */Location/  */LRG/  */Phenotype/  */Regulation/  */Search/ */Share
  				 */UserConfig/  */UserData/  */Variation/
  			      ));
  
    #old views
    push @lines, _lines("Disallow", qw(*/*view));
  
    #other misc views google bot hits
    push @lines, _lines("Disallow", qw(/id/));
    push @lines, _lines("Disallow", qw(/*/psychic));
  
    foreach my $row (('A'..'Z','a'..'z')){
      next if lc $row eq 's';
      push @lines, _lines("Disallow", "*/Gene/$row*", "*/Transcript/$row*");
    }
  
    # a bunch of others that are being bypassed
    foreach my $row (qw(SpeciesTree Similarity SupportingEvidence Sequence_Protein Sequence_cDNA Sequence StructuralVariation_Gene Splice)) {
      push @lines, _lines("Disallow", "*/Gene/$row*", "*/Transcript/$row*");
    }
  
    # links from ChEMBL
    push @lines, _lines("Disallow", "/Gene/Summary");
    push @lines, _lines("Disallow", " /Transcript/Summary");
  
    # Doxygen
    push @lines, _lines("Disallow", "/info/docs/Doxygen");
  
    if (-e "$root/sitemaps/sitemap-index.xml") {
      push @lines, _lines("Sitemap", "http://www.ensembl.org/sitemap-index.xml");
    }
  
    push @lines, _lines("User-agent", "W3C-checklink");
    push @lines, _lines("Allow", "/info");
  
    # Limit Blekkobot's crawl rate to only one page every 20 seconds.
    push @lines, _lines("User-agent", "Blekkobot");
    push @lines, _lines("Crawl-delay", "20");
  
    # stop AhrefsBot indexing us (https://ahrefs.com/robot/)
    push @lines, _lines("User-agent", "AhrefsBot");
    push @lines, _lines("Disallow", "/");
  
    if (-e "$root/sitemaps/sitemap-index.xml") {
      # If we have a sitemap let google know about it.
      warn _box("Creating robots.txt for google sitemap");
      push @lines, _lines("Sitemap", sprintf '%s://%s/sitemap-index.xml', $sd->ENSEMBL_PROTOCOL, $sd->ENSEMBL_SERVERNAME);
    }
  } else {
    push @lines, _lines("User-agent", "*");
    push @lines, _lines("Disallow", "/");
  }

  $lines[0] =~ s/^\n//;

  file_put_contents("$root/robots.txt", @lines);
}

sub _lines { # utility
  my $type = shift;
  return map { sprintf "%s%s: %s\n", $type eq 'User-agent' ? "\n" : '', $type, $_ } @_;
}

sub _box {
  my $text = shift;
  return join("\n", '-' x length $text, $text, '-' x length $text, '');
}

1;
