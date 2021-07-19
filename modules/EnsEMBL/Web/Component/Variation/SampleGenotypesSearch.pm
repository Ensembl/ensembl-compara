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

package EnsEMBL::Web::Component::Variation::SampleGenotypesSearch;

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
  my $sample  = $hub->param('sample');
  
  return $self->_info('A unique location can not be determined for this Variation', $object->not_unique_location) if $object->not_unique_location;  

  my $url = $self->ajax_url('results', { sample => undef });  
  my $id  = $self->id;  

  if (defined($sample)) {
    $sample =~ s/^\W+//;
    $sample =~ s/\s+$//;
  }

  return sprintf('
    <div class="navbar print_hide" style="padding-left:5px">
      <input type="hidden" class="panel_type" value="Content" />
      <form class="update_panel" action="#">
        <label for="sample">Search for a sample:</label>
        <input type="text" name="sample" id="sample" value="%s" size="30"/>
        <input type="hidden" name="panel_id" value="%s" />
        <input type="hidden" name="url" value="%s" />
        <input type="hidden" name="element" value=".results" />
        <input class="fbutton" type="submit" value="Search" />
        <small>(e.g. NA18507)</small>
      </form>
    </div>
    <div class="results">%s</div>
  ', $sample, $id, $url, $self->content_results);
}


sub format_parent {
  my ($self, $parent_data) = @_;
  return ($parent_data && $parent_data->{'Name'}) ? $parent_data->{'Name'} : '-';
}


sub get_table_headings {
  return [
    { key => 'Sample',      title => 'Sample<br /><small>(Male/Female/Unknown)</small>',     sort => 'html', width => '20%', help => 'Sample name and gender'         },
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
  my $sample = $hub->param('sample');
  
  return unless defined $sample;
  
  $sample =~ s/^\W+//;
  $sample =~ s/\s+$//;
  
  my %rows;
  my $flag_children = 0;
  my $html;
  my %sample_data;
   
  my $sample_gt_objs = $object->sample_genotypes_obj;
    
  # Selects the sample genotypes where their sample names match the searched name
  my @matching_sample_gt_objs = (length($sample) > 1 ) ? grep { $_->sample->name =~ /$sample/i } @$sample_gt_objs : ();
    
  if (scalar (@matching_sample_gt_objs)) {
    my %sample_data;
    my $rows;
    my $al_colours = $self->object->get_allele_genotype_colours;    

    # Retrieve sample & sample genotype information
    foreach my $sample_gt_obj (@matching_sample_gt_objs) {
    
      my $genotype = $object->sample_genotype($sample_gt_obj);
      next if $genotype eq '(indeterminate)';
      
      # Colour the genotype
      foreach my $al (keys(%$al_colours)) {
        $genotype =~ s/$al/$al_colours->{$al}/g;
      }
      
      my $sample_obj = $sample_gt_obj->sample;
      my $sample_id  = $sample_obj->dbID;
     
      my $sample_name  = $sample_obj->name;
      my $sample_label = $sample_name;
      if ($sample_label =~ /(1000\s*genomes|hapmap)/i) {
        my @composed_name = split(':', $sample_label);
        $sample_label = $composed_name[$#composed_name];
      }

      my $gender        = $sample_obj->individual->gender;
      my $description   = $object->description($sample_obj);
         $description ||= '-';
      my $population    = $self->get_all_populations($sample_obj);  
         
      my %parents;
      foreach my $parent ('father','mother') {
         my $parent_data   = $object->parent($sample_obj->individual, $parent);
         $parents{$parent} = $self->format_parent($parent_data);
      }         
    
      # Format the content of each cell of the line
      my $row = {
        Sample      => sprintf("<small id=\"%s\">%s (%s)</small>", $sample_name, $sample_label, substr($gender, 0, 1)),
        Genotype    => "<small>$genotype</small>",
        Description => "<small>$description</small>",
        Population  => "<small>$population</small>",
        Father      => "<small>$parents{father}</small>",
        Mother      => "<small>$parents{mother}</small>",
        Children    => '-'
      };
    
      # Children
      my $children      = $object->child($sample_obj->individual);
      my @children_list = map { sprintf "<small>$_ (%s)</small>", substr($children->{$_}[0], 0, 1) } keys %{$children};
    
      if (@children_list) {
        $row->{'Children'} = join ', ', @children_list;
        $flag_children = 1;
      }
        
      push @$rows, $row;
    }

    my $columns = $self->get_table_headings;
    push @$columns, { key => 'Children', title => 'Children<br /><small>(Male/Female)</small>', sort => 'none', help => 'Children names and genders' } if $flag_children;
    
    my $sample_table = $self->new_table($columns, $rows, { data_table => 1, download_table => 1, sorting => [ 'Sample asc' ], data_table_config => {iDisplayLength => 25} });
    $html .= '<div style="margin:0px 0px 50px;padding:0px"><h2>Results for "'.$sample.'" ('.scalar @$rows.')</h2>'.$sample_table->render.'</div>';

  } else {
    $html .= $self->warning_message($sample);
  }

  return qq{<div class="js_panel">$html</div>};
}


sub get_all_populations {
  my $self   = shift;
  my $sample = shift;

  my @pop_names = map { $_->name } @{$sample->get_all_Populations };
  
  return (scalar @pop_names > 0) ? join('; ',sort(@pop_names)) : '-';
}

sub warning_message {
  my $self   = shift;
  my $sample = shift;
  
  return $self->_warning('Not found', qq{No genotype associated with this variant was found for the sample name '<b>$sample</b>'!});
}



1;
