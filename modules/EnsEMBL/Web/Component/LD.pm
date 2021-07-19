=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::LD;

use strict;
use base qw(EnsEMBL::Web::Component::Shared);

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
      $focus ? ['Focus variant:', $focus] : (),
      $self->prediction_method,
      ['Selected population(s):', $self->population_info]
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
  my $object  = $self->object;
  my ($r, $v) = map $hub->param($_), qw(r v);
  my $info;

  return $info if ($object->isa('EnsEMBL::Web::Object::Variation')); # No need to display focus variant information on the LD variant focused view

  if ($v && $hub->param('focus')) {
    my $snp       = $builder->object('Variation');
    my $name      = $snp->name;
    my $source    = $snp->source;
    my $link_name = $hub->get_ExtURL_link($name, 'DBSNP', $name) if ($source eq 'dbSNP' && $hub->species eq 'Homo_sapiens');
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
    estimation between SNPs genotyped in the same samples and within a
    given window. An established method was used to estimate the maximum
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
#  my $loc_object = EnsEMBL::Web::Object::Location->new();
  my $object  = $self->object;
  my $pop_ids = $self->current_pop_id; 
  my $pop_html;

  if (!scalar @$pop_ids) {
    return @{$object->pops_for_slice(100000)}
      ? qq(<p>"Population", "Please select a population from the 'Configure this page' link in the left hand menu."</p>)
      : qq(<p>"Population", "There is no LD data for this species."</p>)
    ;
  }

  foreach my $name (sort { $a cmp $b } map { $self->pop_name_from_id($_) || () } @$pop_ids) {
    my $pop       = $self->pop_obj_from_name($name); 
    my $super_pop = $self->extra_pop($pop->{$name}{'PopObject'}, 'super'); 
#    my $sub_pop   = $self->extra_pop($pop->{$name}{'PopObject'}, 'sub');
    my $html      = $self->print_pop_info($pop,$super_pop);
#    my $html      = $self->print_pop_info($pop, 'Population');
#    $html        .= $self->print_pop_info($super_pop, 'Super-population');
#    $pop_html    .= qq(<table cellspacing="0" cellpadding="0">$html</table>);
    $pop_html .= $html;
  }

  return $pop_html;
}

#-----------------------------------------------------------------------------

sub print_pop_info {
  ### Internal_call
  ### Arg1        : population object
  ### Arg2        : super-population object
  ### Example     : print_pop_info($pop,$super_pop).
  ### Description : Returns information about the population: name, size, description and whether it is a tagged SNP
  ### Returns HTML string with population data

  my ($self, $pop, $super_pop) = @_;
  my $v = $self->hub->param('v');
  my $count;
  my $info;

  foreach my $pop_name (keys %$pop) {
    my $display_pop = $self->pop_url($pop_name, $pop->{$pop_name}{'PopLink'});
    my $size        = $pop->{$pop_name}{'Size'}        || 'unknown'; 
    my $description = $pop->{$pop_name}{'Description'} || 'unknown';
    $description    =~ s/\.\s+.*|\.\,.*/\./; # descriptions are v. long. Stop after 1st "."
    
    my $sp_info = $self->print_super_pop_info($super_pop);
    $info .= qq{
    <li>
    <div>$display_pop</div>
    <div style="padding-left:25px;padding-top:2px">
      <div>
        <div style="float:left;font-weight:bold">Size:</div>
        <div style="float:left;margin-left:5px">$size</div>
        <div style="clear:both"></div>
      </div>
      <div>
        <div style="float:left;font-weight:bold">Description:</div>
        <div style="float:left;margin-left:5px">$description</div>
        <div style="clear:both"></div>
      </div>
      $sp_info
    </div>
    </li>
    };
  }
  $info = qq{<ul style="padding-left:1em">$info</ul>} if ($info ne '');
return $info;
}

sub print_super_pop_info {
  my ($self, $pop) = @_;
  my $info = '';
  foreach my $pop_name (keys %$pop) {
    my $display_pop = $self->pop_url($pop->{$pop_name}{'Name'}, $pop->{$pop_name}{'PopLink'});
    my $size        = $pop->{$pop_name}{'Size'}        || 'unknown';
    my $description = $pop->{$pop_name}{'Description'} || 'unknown';
    $description    =~ s/\.\s+.*|\.\,.*/\./; # descriptions are v. long. Stop after 1st "." 
    $info .= qq{
      <div>
        <div style="float:left;font-weight:bold">Super-Population:</div>
        <div style="float:left;margin-left:5px">$display_pop  |  <b>Size:</b> $size  |  <b>Description:</b> $description</div>
        <div style="clear:both"></div>
      </div>
    };
  }
 
  return $info;
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

  my $hub = $self->hub;

  my @composed_name = split(':', $pop_name);
  if (scalar @composed_name > 1) {
    $composed_name[$#composed_name] = '<b>'.$composed_name[$#composed_name].'</b>';
    $pop_name = join(':', @composed_name);
  }

  return $pop_name if ($hub->species ne 'Homo_sapiens');
  return $pop_name unless $pop_dbSNP;
  return $hub->get_ExtURL_link($pop_name, 'DBSNPPOP', $pop_dbSNP->[0]);
}

#-----------------------------------------------------------------------------
sub current_pop_id {
  my $self = shift;

  my %pops_on = map { $self->hub->param("pop$_") => $_ } grep s/^pop(\d+)$/$1/, $self->hub->param;

  return [keys %pops_on]  if keys %pops_on;
  my $default_pop =  $self->get_default_pop_id;
  warn "*****[ERROR]: NO DEFAULT POPULATION DEFINED.\n\n" unless $default_pop;
  return ( [$default_pop], [] );
}

#-----------------------------------------------------------------------------
sub get_default_pop_id {

  ### Example : my $pop_id = $self->DataObj->get_default_pop_is
  ### Description : returns population id for default population for this species
  ### Returns population dbID

  my $self = shift;
  my $variation_db = $self->hub->database('variation')->get_db_adaptor('variation');
  my $pop_adaptor = $variation_db->get_PopulationAdaptor;
  my $pop = $pop_adaptor->fetch_default_LDPopulation();
  return unless $pop;
  return $pop->dbID;
}

#-----------------------------------------------------------------------------
sub pop_obj_from_name {

  ### Arg1    : Population name
  ### Example : my $pop_name = $self->DataObj->pop_obj_from_name($pop_id);
  ### Description : returns population info for the given population name
  ### Returns population object

  my $self = shift;
  my $pop_name = shift;
  my $variation_db = $self->hub->database('variation')->get_db_adaptor('variation');
  my $pa  = $variation_db->get_PopulationAdaptor;
  my $pop = $pa->fetch_by_name($pop_name);
  return {} unless $pop;
  my $data = $self->format_pop( [$pop] );
  return $data;
}

#-----------------------------------------------------------------------------
sub pop_name_from_id {

  ### Arg1 : Population id
  ### Example : my $pop_name = $self->DataObj->pop_name_from_id($pop_id);
  ### Description : returns population name as string
  ### Returns string

  my $self = shift;
  my $pop_id = shift;
  return $pop_id if $pop_id =~ /\D+/ && $pop_id !~ /^\d+$/;

  my $variation_db = $self->hub->database('variation')->get_db_adaptor('variation');
  my $pa  = $variation_db->get_PopulationAdaptor;
  my $pop = $pa->fetch_by_dbID($pop_id);
  return "" unless $pop;
  return $pop->name;
}

#-----------------------------------------------------------------------------
sub extra_pop {  ### ALSO IN SNP DATA OBJ

  ### Arg1 : Bio::EnsEMBL::Variation::Population object
  ### Arg[2]      : string "super", "sub"
  ### Example : $genotype_freq = $self->DataObj->extra_pop($pop, "super");
  ### Description : gets any super/sub populations
  ### Returns String

  my ($self, $pop_obj, $type)  = @_;
  return {} unless $pop_obj;
  my $call = "get_all_$type" . "_Populations";
  my @populations = @{ $pop_obj->$call};
  return  $self->format_pop(\@populations);
}

#-----------------------------------------------------------------------------
sub format_pop {

  ### Arg1 : population object
  ### Example : my $data = $self->format_pop
  ### Description : returns population info for the given population obj
  ### Returns hashref

  my $self = shift;
  my $pops = shift;
  my %data;
  foreach (@$pops) {
    my $name = $_->name;
    $data{$name}{Name}       = $name;
    $data{$name}{dbID}       = $_->dbID;
    $data{$name}{Size}       = $_->size;
    $data{$name}{PopLink}    = $_->get_all_synonyms("dbSNP");
    $data{$name}{Description}= $_->description;
    $data{$name}{PopObject}  = $_;  ## ok maybe this is cheating..
  }
  return \%data;
}

#-----------------------------------------------------------------------------

1;
