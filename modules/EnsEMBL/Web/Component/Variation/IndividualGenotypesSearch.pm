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

package EnsEMBL::Web::Component::Variation::IndividualGenotypesSearch;

use strict;
use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::Component::Variation);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}

sub content {
  my $self   = shift;
  my $object = $self->object;
  my $hub    = $self->hub;
  my $indiv  = $hub->param('ind');
  
  return $self->_info('A unique location can not be determined for this Variation', $object->not_unique_location) if $object->not_unique_location;  

  my $url = $self->ajax_url('results', { ind => undef });  
  my $id  = $self->id;  

  if (defined($indiv)) {
    $indiv =~ s/^\W+//;
    $indiv =~ s/\s+$//;
  }

  return sprintf('
    <div class="navbar print_hide" style="padding-left:5px">
      <input type="hidden" class="panel_type" value="Content" />
      <form class="update_panel" action="#">
        <label for="ind">Search for an individual:</label>
        <input type="text" name="ind" id="ind" value="%s" size="30"/>
        <input type="hidden" name="panel_id" value="%s" />
        <input type="hidden" name="url" value="%s" />
        <input type="hidden" name="element" value=".results" />
        <input class="fbutton" type="submit" value="Search" />
        <small>(e.g. NA18507)</small>
      </form>
    </div>
    <div class="results">%s</div>
  ', $indiv, $id, $url, $self->content_results);
}


sub format_parent {
  my ($self, $parent_data) = @_;
  return ($parent_data && $parent_data->{'Name'}) ? $parent_data->{'Name'} : '-';
}


sub get_table_headings {
  return [
    { key => 'Individual',  title => 'Individual<br /><small>(Male/Female/Unknown)</small>', sort => 'html', width => '20%', help => 'Individual name and gender'     },
    { key => 'Genotype',    title => 'Genotype<br /><small>(forward strand)</small>',        sort => 'html', width => '15%', help => 'Genotype on the forward strand' },
    { key => 'Description', title => 'Description',                                          sort => 'html'                                                           },
    { key => 'Population',  title => 'Population(s)',                                        sort => 'html'                                                           },
    { key => 'Father',      title => 'Father',                                               sort => 'none'                                                           },
    { key => 'Mother',      title => 'Mother',                                               sort => 'none'                                                           }
  ];
}


sub content_results {
  my $self   = shift;
  my $object = $self->object;
  my $hub    = $self->hub;
  my $indiv  = $hub->param('ind');
  
  return unless defined $indiv;
  
  $indiv =~ s/^\W+//;
  $indiv =~ s/\s+$//;
  
  my %rows;
  my $flag_children = 0;
  my $html;
  my %ind_data;
   
  my $ind_gt_objs = $object->individual_genotypes_obj;
    
  # Selects the individual genotypes where their individual names match the searched name
  my @matching_ind_gt_objs = (length($indiv) > 1 ) ? grep { $_->individual->name =~ /$indiv/i } @$ind_gt_objs : ();
    
  if (scalar (@matching_ind_gt_objs)) {
    my %ind_data;
    my $rows;
    my $al_colours = $self->object->get_allele_genotype_colours;    

    # Retrieve individidual & individual genotype information
    foreach my $ind_gt_obj (@matching_ind_gt_objs) {
    
      my $genotype = $object->individual_genotype($ind_gt_obj);
      next if $genotype eq '(indeterminate)';
      
      # Colour the genotype
      foreach my $al (keys(%$al_colours)) {
        $genotype =~ s/$al/$al_colours->{$al}/g;
      }
      
      my $ind_obj = $ind_gt_obj->individual;
      my $ind_id  = $ind_obj->dbID;
     
      my $ind_name      = $ind_obj->name;
      my $gender        = $ind_obj->gender;
      my $description   = $object->individual_description($ind_obj);
         $description ||= '-';
      my $population    = $self->get_all_populations($ind_obj);  
         
      my %parents;
      foreach my $parent ('father','mother') {
         my $parent_data   = $object->parent($ind_obj,$parent);
         $parents{$parent} = $self->format_parent($parent_data);
      }         
    
      # Format the content of each cell of the line
      my $row = {
        Individual  => sprintf("<small>$ind_name (%s)</small>", substr($gender, 0, 1)),
        Genotype    => "<small>$genotype</small>",
        Description => "<small>$description</small>",
        Population  => "<small>$population</small>",
        Father      => "<small>$parents{father}</small>",
        Mother      => "<small>$parents{mother}</small>",
        Children    => '-'
      };
    
      # Children
      my $children      = $object->child($ind_obj);
      my @children_list = map { sprintf "<small>$_ (%s)</small>", substr($children->{$_}[0], 0, 1) } keys %{$children};
    
      if (@children_list) {
        $row->{'Children'} = join ', ', @children_list;
        $flag_children = 1;
      }
        
      push @$rows, $row;
    }

    my $columns = $self->get_table_headings;
    push @$columns, { key => 'Children', title => 'Children<br /><small>(Male/Female)</small>', sort => 'none', help => 'Children names and genders' } if $flag_children;
    
    my $ind_table = $self->new_table($columns, $rows, { data_table => 1, download_table => 1, sorting => [ 'Individual asc' ], data_table_config => {iDisplayLength => 25} });
    $html .= '<div style="margin:0px 0px 50px;padding:0px"><h2>Results for "'.$indiv.'" ('.scalar @$rows.')</h2>'.$ind_table->render.'</div>';

  } else {
    $html .= $self->warning_message($indiv);
  }

  return qq{<div class="js_panel">$html</div>};
}


sub get_all_populations {
  my $self       = shift;
  my $individual = shift;

  my @pop_names = map { $_->name } @{$individual->get_all_Populations };
  
  return (scalar @pop_names > 0) ? join('; ',sort(@pop_names)) : '-';
}

sub warning_message {
  my $self  = shift;
  my $indiv = shift;
  
  return $self->_warning('Not found', qq{No genotype associated with this variant was found for the individual name '<b>$indiv</b>'!});
}



1;
