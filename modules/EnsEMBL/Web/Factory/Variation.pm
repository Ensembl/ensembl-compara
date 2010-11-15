package EnsEMBL::Web::Factory::Variation;

use strict;
use warnings;
no warnings 'uninitialized';

use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::Factory);

sub createObjects {
  my $self       = shift;
  my $variation  = shift;
  my $identifier = $self->param('v') || $self->param('snp');
  
  my $db = $self->species_defs->databases->{'DATABASE_VARIATION'};
  
  return $self->problem('fatal', 'Database Error', 'There is no variation database for this species.') unless $db;
  
  if (!$variation) {
    return $self->problem('fatal', 'Variation ID required', $self->_help('A variation ID is required to build this page.')) unless $identifier;
    
    my $dbs = $self->hub->get_databases(qw(core variation));
    
    return $self->problem('fatal', 'Database Error', 'Could not connect to the core database.') unless $dbs;
    
    my $variation_db = $dbs->{'variation'};
    
    return $self->problem('fatal', 'Database Error', 'Could not connect to the variation database.') unless $variation_db;
    
    $variation_db->dnadb($dbs->{'core'});
    
    $variation = $variation_db->get_VariationAdaptor->fetch_by_name($identifier, $self->param('source'));
  }
  
  if ($variation) {
    $self->DataObjects($self->new_object('Variation', $variation, $self->__data));
    
    my $vf                  = $self->param('vf');
    my @variation_features  = @{$variation->get_all_VariationFeatures};
    my ($variation_feature) = scalar @variation_features == 1 ? $variation_features[0] : $vf ? grep $_->dbID eq $vf, @variation_features : undef;
    
    # If the variation has only one VariationFeature, or if a vf parameter is supplied which matches one of the VariationFeatures,
    # generate a location based on that VariationFeature.
    # If not, delete the vf parameter because it does not map to this variation
    if ($variation_feature) {
      my $context = $self->param('context') || 500;
      $self->generate_object('Location', $variation_feature->feature_Slice->expand($context, $context));
      $self->param('vf', $variation_feature->dbID) unless $vf eq $variation_feature->dbID; # This check is needed because ZMenu::TextSequence uses an array of v and vf parameters. The check stops being unecessarily overwritten
    } elsif ($vf) {
      $self->delete_param('vf');
    }
    
    $self->param('vdb', 'variation');
    $self->param('v', $variation->name) unless $identifier eq $variation->name; # For same reason as vf check above
  } else { 
    my $dbsnp_version = $db->{'dbSNP_VERSION'} ? "which includes data from dbSNP $db->{'dbSNP_VERSION'}," : '';
    my $help_message  = "Either $identifier does not exist in the current Ensembl database, $dbsnp_version or there was a problem retrieving it.";
    return $self->problem('fatal', "Could not find variation $identifier", $self->_help($help_message));
  }
}

sub _help {
  my ($self, $string) = @_;

  my %sample    = %{$self->species_defs->SAMPLE_DATA || {}};
  my $help_text = $string ? sprintf '<p>%s</p>', encode_entities($string) : '';
  my $url       = $self->hub->url({ __clear => 1, action => 'Summary', v => $sample{'VARIATION_PARAM'} });

  $help_text .= sprintf('
    <p>
      This view requires a variation identifier in the URL. For example:
    </p>
    <blockquote class="space-below"><a href="%s">%s</a></blockquote>',
    encode_entities($url),
    encode_entities($self->species_defs->ENSEMBL_BASE_URL. $url)
  );

  return $help_text;
}

1;
