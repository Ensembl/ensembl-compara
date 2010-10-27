# $Id$

package EnsEMBL::Web::Apache::DasHandler;

use strict;

use Apache2::Const qw(:common :http :methods);

use SiteDefs qw(:APACHE);

use Bio::EnsEMBL::Registry;

use EnsEMBL::Web::Controller::DAS;

sub handler_das {
  my ($r, $cookies, $das_species, $path_segments, $querystring) = @_;
  
  my $DSN = $path_segments->[0];
  
  # These are static content files due to the time to generate.
  # These files are created by utils/initialised_das.pl
  # Fall through - this is a static page
  return undef if $DSN =~ /^(sources|dsn)$/ || ($path_segments->[1] eq 'entry_points' && -e "$ENSEMBL_SERVERROOT/htdocs/das/$DSN/entry_points");
  
  # We have a DAS URL of the form
  # /das/{species}.{assembly}.{feature_type}/command
  # 
  # feature_type consists of type and subtype separated by a -
  # e.g. gene-core-ensembl
  #
  # command is e.g. features, 
  my @dsn_fields = split /\./, $DSN;
  
  shift @dsn_fields; # remove the species
  
  my $type     = pop @dsn_fields;
  my $assembly = join '.', @dsn_fields;
  my $subtype;
  
  ($type, $subtype) = split /-/, $type, 2;
  my $command = $path_segments->[1];
  
  return DECLINED unless $command;
  
  # DAS sources based on ensembl gene ids are species-independent
  # We will have a DAS URL of the form
  # /das/Multi.Ensembl-GeneID.{feature_type}/command  but you can still call
  # /das/Homo_sapiens.Ensembl-GeneID.{feature_type}/command
  # then the request will be restricted to Human db
  if ($assembly =~ /geneid/i && $das_species =~ /multi/i) {
    # this a site-wide request - try to figure out the species from the ID
    $das_species = '';
    
    if ($querystring =~ /segment=([^;]+)/) {
      my ($s) = Bio::EnsEMBL::Registry->get_species_and_object_type($1, 'Gene');
      $das_species = $s if $s;
    }
    
    # in case no macth was found go to the default site species to report the page with no features
    $das_species ||= $ENSEMBL_PRIMARY_SPECIES;
  }
  
  return DECLINED unless $das_species;
  
  $ENV{'ENSEMBL_SPECIES'}      = $das_species;
  $ENV{'ENSEMBL_DAS_ASSEMBLY'} = $assembly;
  $ENV{'ENSEMBL_DAS_TYPE'}     = $type;
  $ENV{'ENSEMBL_TYPE'}         = 'DAS';
  $ENV{'ENSEMBL_DAS_SUBTYPE'}  = $subtype;
  $ENV{'ENSEMBL_SCRIPT'}       = $command;
 
  ## Access control headers - supported by ProServer and Dazzle
  $r->headers_out->add(
    'Access-Control-Allow-Origin'   => '*',
    'Access-Control-Expose-Headers' => 'X-DAS-Version X-DAS-Status X-DAS-Capabilities',
  );
 
  new EnsEMBL::Web::Controller::DAS($r, $cookies);
  
  return OK;
}

1;
