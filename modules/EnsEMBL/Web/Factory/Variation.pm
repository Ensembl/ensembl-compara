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

package EnsEMBL::Web::Factory::Variation;

use strict;
use warnings;
no warnings 'uninitialized';

use HTML::Entities qw(encode_entities);
use Scalar::Util qw(isweak);

use base qw(EnsEMBL::Web::Factory);

sub createObjects {
  my $self        = shift;
  my $variation   = shift;
  my $hub         = $self->hub;
  my $identifier  = $self->param('v') || $self->param('snp');
  my $db          = $hub->species_defs->databases->{'DATABASE_VARIATION'};
  
  return $self->problem('fatal', 'Database Error', 'There is no variation database for this species.') unless $db;
  
  if (!$variation) {
    my $core_db = $hub->database('core');
    
    return $self->problem('fatal', 'Database Error', 'Could not connect to the core database.') unless $core_db;
    
    my $variation_db = $self->hub->database('variation');
       $variation_db->include_non_significant_phenotype_associations(0);

    return $self->problem('fatal', 'Database Error', 'Could not connect to the variation database.') unless $variation_db;
    
    $variation_db->dnadb($core_db);

    my $vfid = $self->param('vf');

    if($identifier) {
      $variation = $variation_db->get_VariationAdaptor->fetch_by_name($identifier);
    }

    if(!$variation && $vfid) {
      if(my $vf = $variation_db->get_VariationFeatureAdaptor->fetch_by_dbID($vfid)) {
        $identifier = $vf->variation_name;
        $self->param('v',$identifier);
        $variation = $vf->variation;

        $variation->{variation_feature} = $vf if isweak($variation->{variation_feature});
      }
    }
  }
  
  if ($variation) {
    $self->DataObjects($self->new_object('Variation', $variation, $self->__data));
    
    my @vf                  = $self->param('vf');
    my @variation_features  = @{$variation->get_all_VariationFeatures};
    my ($variation_feature) = scalar @variation_features == 1 ? $variation_features[0] : $vf[0] ? grep $_->dbID eq $vf[0], @variation_features : undef;
    
    # If the variation has only one VariationFeature, or if a vf parameter is supplied which matches one of the VariationFeatures,
    # generate a location based on that VariationFeature.
    # If not, delete the vf parameter because it does not map to this variation
    if ($variation_feature) {
      my $context = $self->param('context') || 500;
      $self->generate_object('Location', $variation_feature->feature_Slice->expand($context, $context));
      $self->param('vf', $variation_feature->dbID) unless scalar @vf > 1; # This check is needed because ZMenu::TextSequence uses an array of v and vf parameters - don't overwrite with a single value
    } elsif (scalar @vf) {
      $self->delete_param('vf');
    }
    
    $self->param('vdb', 'variation') unless $self->param('vdb');
    $self->param('v', $variation->name) unless $self->param('v'); # For same reason as vf check above
    $self->delete_param('snp');
  } else { 
    my $dbsnp_version = $db->{'dbSNP_VERSION'} ? "which includes data from dbSNP $db->{'dbSNP_VERSION'}," : '';
    my $help_message  ="Either $identifier does not exist in the current Ensembl database, $dbsnp_version or there was a problem retrieving it.";
    my $help_extra;
    if ($self->species eq 'Homo_sapiens') {
      $help_extra = sprintf('Note: If the NCBI has released a new build since %s for Human, there may be new variants which have not yet been incorporated into Ensembl. If this is the case, you may find information about this %s on the NCBI website: <a href="http://www.ncbi.nlm.nih.gov/sites/entrez?db=snp&cmd=search&term=%s" target="external">http://www.ncbi.nlm.nih.gov/sites/entrez?db=snp&cmd=search&term=%s</a>.',
                            $db->{'dbSNP_VERSION'},
                            $identifier,$identifier,$identifier);
      return $self->problem('fatal', "Could not find variation $identifier", $self->_help($help_message,$help_extra));
    }
    elsif ($hub-$species_defs->ENSEMBL_SUBTYPE eq 'Rapid Release') {
      my $message = sprintf('Variants on this site are served from VCF files, which cannot be searched by ID. Please visit "Region in Detail" and enter the coordinates for %s to view variation tracks in this location.', $hub->param('v'));
      return $self->problem('fatal', 'Unable to search for variation IDs', $message);
    }
    else {
      return $self->problem('fatal', "Could not find variation $identifier", $self->_help($help_message,$help_extra));
    }
  }
}

sub _help {
  my ($self, $string, $help_extra) = @_;
  my %sample    = %{$self->species_defs->SAMPLE_DATA || {}};
  my $help_text = $string ? sprintf '<p>%s</p>', encode_entities($string) : '';
  my $url       = $self->hub->url({ __clear => 1, action => 'Explore', v => $sample{'VARIATION_PARAM'} });
  $help_text .= "$help_extra" if $help_extra;
  $help_text .= sprintf('
    <p>
      <br />This view requires a variation identifier in the URL. For example:
    </p>
    <div class="left-margin bottom-margin word-wrap"><a href="%s">%s</a></div>',
    encode_entities($url),
    encode_entities($self->species_defs->ENSEMBL_BASE_URL. $url)
  );

  return $help_text;
}

1;
