=head1 LICENSE
Copyright [2017-2022] EMBL-European Bioinformatics Institute
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

package EnsEMBL::Web::Component::Phenotype::OntologySummary;



use strict;

use HTML::Entities qw(encode_entities);

use EnsEMBL::Web::Controller::SSI;
use EnsEMBL::Web::Exceptions;

use base qw(EnsEMBL::Web::Component::Phenotype);
use Data::Dumper;

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub content {
  my $self = shift;
  my $hub  = $self->hub; 

  my $html;

  if ($hub->param('ph')) {
    $html .= $self->get_phe_ontology();
  }

  if ($hub->param('oa')) {
    my $ontology_accession = $hub->param('oa');

    ## look up term info
    my $adaptor = $hub->database('go')->get_OntologyTermAdaptor;
    my $ontologyterm = $adaptor->fetch_by_accession($ontology_accession);
   
    my $external_link = $self->external_ontology_link($hub->param('oa'));

    if (defined $ontologyterm ) {
      $external_link .= " (".$ontologyterm->ontology.")" if ($external_link and $external_link ne '');
      my $summary_table = $self->new_twocol( [ 'Term',       '<b>'. $ontologyterm->name().'</b>'],
                                             [ 'Accession',  $external_link],
                                             [ 'Definition', (split/\"/,$ontologyterm->definition())[1]]
                                           );
      $html .= $summary_table->render;
    }
    else{
     $html .= '<b>View '. $external_link . ' ontology information at source</b><p>';
    }  
  }
  return $html;
}

sub get_phe_ontology {
  my $self = shift;
  my $hub  = $self->hub;
  my $object = $self->object;

  my $phe_desc = $object->get_phenotype_desc;

  ## Find matching ontology terms
  my $ontol_data =  $self->get_all_ontology_data();

  return $self->_warning("No ontology mapping!", "Can't find an ontology mapping for the phenotype/disease/trait $phe_desc!") unless $ontol_data;

  my $html;

  my @ontol_acc = keys(%{$ontol_data});

  if (scalar(@ontol_acc) > 1 || 
     (scalar(@ontol_acc) == 1 && !$hub->param('oa')) || 
     (scalar(@ontol_acc) == 1 && $hub->param('oa') && !$ontol_data->{$hub->param('oa')})) {
    my $header = "Ontology terms associated with $phe_desc";

    my $params = $hub->core_params;
    # ignore ph and oa as we want them to be overwritten
    my $core_params = join '', map $params->{$_} && $_ ne 'oa' ? qq(<input name="$_" value="$params->{$_}" type="hidden" />) : (), keys %$params;

    my @oas;
    foreach my $acc (keys %{$ontol_data}){
      push @oas, {
        value    => $acc,
        name     => "$acc - ".$ontol_data->{$acc}->{name},
        selected => ($hub->param('oa') && $hub->param('oa') eq $acc) ? ' selected' : ''
      };
    }

    my $options = join '', map qq(<option value="$_->{'value'}"$_->{'selected'}>$_->{'name'}</option>), @oas;

    my $label = $self->hub->param('oa') ? 'Selected term' : 'Select term';

    $html .= sprintf('<form action="%s" method="get"><b>%s</b>: %s<select name="oa" class="fselect">%s</select> <input value="Go" class="fbutton" type="submit"></form>',
                    $hub->url({ ph => $hub->param('ph') }),
                    $label,
                    $core_params,
                    $options,
    );

    return $self->_info($header, $html, '80%');
  }
  else {
    return '';
  }
}


1;
