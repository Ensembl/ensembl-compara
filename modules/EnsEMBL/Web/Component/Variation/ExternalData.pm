package EnsEMBL::Web::Component::Variation::ExternalData;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Variation);
use CGI qw(escapeHTML);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  1 );
}


sub content {
  my $self = shift;
  my $object = $self->object;
  my $html = '';

  ## first check we have uniquely determined variation
  unless ($object->core_objects->{'parameters'}{'vf'} ){
    $html = "<p>You must select a location from the panel above to see this information</p>";
    return $self->_info(
    'A unique location can not be determined for this Variation',
    $html
    );
  }

  my @data = @{$object->get_external_data};
  unless (scalar @data >= 1) { return "We do not have any external data for this variation";}
  
  $html .=  qq(<dl class="summary">);

  foreach my $va ( @data){
    my $disorder = $va->phenotype_description(); 
    my $code = $va->phenotype_name();
    my $url = $object->species_defs->ENSEMBL_EXTERNAL_URLS->{'EGA'};
    my $ext_id = $va->local_stable_id(); 
    $url =~s/###ID###/$ext_id/;
    $url =~s/###D###/$code/;
    my $source = $va->source_name();
    my $link = "<a href=" .$url .">[$source]</a>";
    my $text = $object->name . " had a significant p-value in Genome Wide Association Study (" .$va->study_type() . ") " . $link; 
    $html .= "<dt>$disorder ($code)</dt><dd>$text</dd>";
  }
    
  $html .= "</dl>";
  return $html;
}

1;
