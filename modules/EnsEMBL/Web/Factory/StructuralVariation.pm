package EnsEMBL::Web::Factory::StructuralVariation;

use strict;
use warnings;
no warnings 'uninitialized';

use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::Factory);

sub createObjects {
  my $self      = shift; 
  my $structural_variation = shift; 
  my $identifier;
  
  my $db = $self->species_defs->databases->{'DATABASE_VARIATION'};
  return $self->problem ('fatal', 'Database Error', 'There is no variation database for this species.') unless $db;
   
  if (!$structural_variation) {
    my $dbs  = $self->hub->get_databases(qw(core variation));;
    
    return $self->problem('fatal', 'Database Error', 'Could not connect to the core database.') unless $dbs;
    
    my $variation_db = $dbs->{'variation'};
    $variation_db->include_failed_variations(1);
     
    return $self->problem('fatal', 'Database Error', 'Could not connect to the variation database.') unless $variation_db;
    
    $identifier = $self->param('sv');
    
    return $self->problem('fatal', 'Structural Variation ID required', $self->_help('A structural variation ID is required to build this page.')) unless $identifier;
    
    $structural_variation = $variation_db->get_StructuralVariationAdaptor->fetch_by_name($identifier);
  }
  
  if ($structural_variation) { 
    $self->DataObjects($self->new_object('StructuralVariation', $structural_variation, $self->__data));
    
    my @svf           = $self->param('svf');
    
    my @sv_features  = @{$structural_variation->get_all_StructuralVariationFeatures};
    my ($sv_feature) = scalar @sv_features == 1 ? $sv_features[0] : $svf[0] ? grep $_->dbID eq $svf[0], @sv_features : undef;
    
		if ($sv_feature) {
      my $context = $self->param('context') || 500;
      $self->generate_object('Location', $sv_feature->feature_Slice->expand($context, $context));
    	$self->param('svf', $sv_feature->dbID) unless scalar @svf > 1; # This check is needed
		} elsif (scalar @svf) {
      $self->delete_param('svf');
    }
    
    $self->param('vdb', 'variation');
    $self->param('sv', $structural_variation->variation_name) unless $self->param('sv'); # For same reason as svf check above;
  } else { 
    my $dbsnp_version = "";
    if ( $self->species_defs->databases->{'DATABASE_VARIATION'}->{'dbSNP_VERSION'}){
      $dbsnp_version = "which includes data from dbSNP ". $self->species_defs->databases->{'DATABASE_VARIATION'}->{'dbSNP_VERSION'} .',';
    }
    my $help_message = "Either $identifier does not exist in the current Ensembl database, $dbsnp_version or there was a problem retrieving it.";
    return $self->problem('fatal', "Could not find structural variation $identifier", $self->_help($help_message));
  }
}

sub _help {
  my ($self, $string) = @_;

  my %sample    = %{$self->species_defs->SAMPLE_DATA || {}};
  my $help_text = $string ? sprintf '<p>%s</p>', encode_entities($string) : '';
  my $url       = $self->hub->url({ __clear => 1, action => 'Summary', sv => $sample{'STRUCTURAL_VARIATION_PARAM'} });

  $help_text .= sprintf('
    <p>
      This view requires a structural variation identifier in the URL. For example:
    </p>
    <blockquote class="space-below"><a href="%s">%s</a></blockquote>',
    encode_entities($url),
    encode_entities($self->species_defs->ENSEMBL_BASE_URL. $url)
  );

  return $help_text;
}

1;
