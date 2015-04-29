=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::Location::LD;

use strict;

use base qw(EnsEMBL::Web::Component::Location);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}

sub content {
  my $self  = shift;
  my $focus = $self->focus;
  if ($self->hub->param('pop1')) {
    return $self->new_twocol(
      $focus ? ['Focus:', $focus] : (),
      $self->prediction_method,
      ['Populations:', $self->population_info]
    )->render;
  }

  return $self->_info('No Population Selected', '<p>You must select a population(s) using the "Select populations" link from menu on the left hand side of this page.</p>');
}

#-----------------------------------------------------------------------------

sub focus {
  ### Information_panel
  ### Purpose : outputs focus of page e.g.. gene, SNP (rs5050)or slice
  ### Description : adds pair of values (type of focus e.g gene or snp and the ID) to panel if the paramater "gene" or "snp" is defined

  my $self    = shift;
  my $builder = $self->builder;
  my $hub     = $self->hub;
  my ($r, $v) = map $hub->param($_), qw(r v);
  my $info;
  
  if ($v && $hub->param('focus')) {
    my $snp       = $builder->object('Variation');
    my $name      = $snp->name; 
    my $source    = $snp->source;
    my $link_name = $hub->get_ExtURL_link($name, 'DBSNP', $name) if $source eq 'dbSNP'; 
    my $url       = $hub->url({ type => 'Variation', action => 'Explore', v => $v, vf => $hub->param('vf') });
    
    $info = sprintf 'Variant %s (%s %s) <a href="%s">[View variation]</a>', $link_name, $source, $snp->Obj->adaptor->get_source_version($source), $url;
  } elsif ($r) {
    my $url = $hub->url({ type => 'Location', action => 'View', r => $r });
    
    $info = qq{Location <a href="$url">$r</a>};
  }
  
  return $info;
}

#-----------------------------------------------------------------------------

sub prediction_method {
  ### Information_panel
  ### Purpose: standard blurb about calculation of LD
  ### Description : Adds text information about the prediction method

  return ['Prediction method', 'LD values were calculated by a pairwise
    estimation between SNPs genotyped in the same individuals and within a
    100kb window. An established method was used to estimate the maximum
    likelihood of the proportion that each possible haplotype contributed to the
    double heterozygote.'
  ];
}

#-----------------------------------------------------------------------------

sub population_info {
  ### Information_panel
  ### Purpose    : outputs name, size, description of population and
  ### super/sub population info if exists
  ### Description : Returns information about the population.  Calls helper function print_pop_info to get population data (name, size, description, whether the SNP is tagged)

  my $self    = shift;
  my $object  = $self->object;
  my $pop_ids = $object->current_pop_id; 
  my $pop_html;

  if (!scalar @$pop_ids) {
    return @{$object->pops_for_slice(100000)}
      ? qq(<p>"Population", "Please select a population from the 'Configure this page' link in the left hand menu."</p>)
      : qq(<p>"Population", "There is no LD data for this species."</p>)
    ;
  }

  foreach my $name (sort { $a cmp $b } map { $object->pop_name_from_id($_) || () } @$pop_ids) {
    my $pop       = $object->pop_obj_from_name($name); 
    my $super_pop = $object->extra_pop($pop->{$name}{'PopObject'}, 'super'); 
    my $sub_pop   = $object->extra_pop($pop->{$name}{'PopObject'}, 'sub');
    my $html      = $self->print_pop_info($pop, 'Population');
    $html        .= $self->print_pop_info($super_pop, 'Super-population');
    $pop_html    .= qq(<table cellspacing="0" cellpadding="0">$html</table>);
  }

  return $pop_html;
}

#-----------------------------------------------------------------------------

sub print_pop_info {
  ### Internal_call
  ### Arg1        : population object
  ### Arg2        : label (e.g. "Super-Population" or "Sub-Population")
  ### Example     : print_pop_info($super_pop, "Super-Population").
  ### Description : Returns information about the population: name, size, description and whether it is a tagged SNP
  ### Returns HTML string with population data

  my ($self, $pop, $label) = @_;
  my $v = $self->hub->param('v');
  my $count;
  my $row;

  foreach my $pop_name (keys %$pop) {
    my $display_pop = $self->pop_url($pop->{$pop_name}{'Name'}, $pop->{$pop_name}{'PopLink'});
    my $size        = $pop->{$pop_name}{'Size'}        || 'unknown'; 
    my $description = $pop->{$pop_name}{'Description'} || 'unknown';
    $description    =~ s/\.\s+.*|\.\,.*/\./; # descriptions are v. long. Stop after 1st "."
    
    $row .= "<th><p>$label:&nbsp;</p></th><td><p>$display_pop &nbsp;[size: $size]</p></td></tr>";
    $row .= "<tr><th><p>Description:&nbsp;</p></th><td><p>$description</p></td>";

    if ($v && $label eq 'Population') {
      my $tagged = $self->tagged_snp($pop->{$pop_name}{'Name'});
      $row .= "<tr><th><p>SNP in tagged set for this population:&nbsp;</p></th><td><p>$tagged</p></td>" if $tagged;
    }
  }
  
  return "<tr>$row</tr>";
}

#-----------------------------------------------------------------------------

sub tagged_snp {
  ### Arg1 : object
  ### Arg2 : population name (string)
  ### Description : Gets the {{EnsEMBL::Web::Object::SNP}} object off the
  ### proxy object and checks if SNP is tagged in the current population.
  ### Returns 0 if no SNP.
  ### Returns "Yes" if SNP is tagged in the population name supplied, else
  ### returns no

  my ($self, $pop_name)  = @_;
  my $snp      = $self->builder->object('Variation');   
  my $snp_data = $snp->tagged_snp;
  
  return unless keys %$snp_data;

  for my $pop_id (keys %$snp_data) {
    return 'Yes' if $pop_id eq $pop_name;
  }
  
  return 'No';
}

#-----------------------------------------------------------------------------
sub pop_url {
  ### Internal_call
  ### Arg 1       : Population name (to be displayed)
  ### Arg 2       : dbSNP population ID (variable to be linked to)
  ### Example     : $self->pop_url($pop_name, $pop_dbSNPID);
  ### Description : makes pop_name into a link
  ### Returns HTML string of link to population in dbSNP

  my ($self, $pop_name, $pop_dbSNP) = @_;
  return $pop_name unless $pop_dbSNP;
  return $self->hub->get_ExtURL_link($pop_name, 'DBSNPPOP', $pop_dbSNP->[0]);
}

1;
