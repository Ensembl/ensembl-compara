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

package EnsEMBL::Web::Component::Variation::IndividualGenotypes;

use strict;

use base qw(EnsEMBL::Web::Component::Variation);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}

sub content {
  my $self         = shift;
  my $object       = $self->object;
  my $hub          = $self->hub;
  my $selected_pop = $hub->param('pop');
  
  
  my $pop_obj  = $selected_pop ? $self->hub->get_adaptor('get_PopulationAdaptor', 'variation')->fetch_by_dbID($selected_pop) : undef;
  my %ind_data = %{$object->individual_table($pop_obj)};

  return sprintf '<h3>No individual genotypes for this SNP%s %s</h3>', $selected_pop ? ' in population' : '', $pop_obj->name unless %ind_data;

  my (%rows, %pop_names);
  my $flag_children = 0;
  my $allele_string = $self->object->alleles;
  my $al_colours = $self->object->get_allele_genotype_colours;

  my %group_name;
  my %priority_data;
  my %other_pop_data;
  my %other_ind_data;

  foreach my $ind_id (sort { $ind_data{$a}{'Name'} cmp $ind_data{$b}{'Name'} } keys %ind_data) {
    my $data     = $ind_data{$ind_id};
    my $genotype = $data->{'Genotypes'};
    
    next if $genotype eq '(indeterminate)';
    
    my $father      = $self->format_parent($data->{'Father'});
    my $mother      = $self->format_parent($data->{'Mother'});
    my $description = $data->{'Description'} || '-';
    my %populations;
    
    my $other_ind = 0;
    
    foreach my $pop(@{$data->{'Population'}}) {
      my $pop_id = $pop->{'ID'};
      next unless ($pop_id);
      
      if ($pop->{'Size'} == 1) {
        $other_ind = 1;
        $other_ind_data{$pop_id} = 1;
      }
      else {
        $populations{$pop_id} = 1;
        $pop_names{$pop_id} = $pop->{'Name'};

        my $priority_level = $pop->{'Priority'};
        if ($priority_level) {
          $group_name{$priority_level} = $pop->{'Group'} unless defined $group_name{$priority_level};
          $priority_data{$priority_level}{$pop_id} = {'name' => $pop->{'Name'}, 'link' => $pop->{'Link'}};
        }
        else {
          $other_pop_data{$pop_id} = {'name' => $pop->{'Name'}, 'link' => $pop->{'Link'}};
        }
      }
    }
    
    # Colour the genotype
    foreach my $al (keys(%$al_colours)) {
      $genotype =~ s/$al/$al_colours->{$al}/g;
    } 
    
    my $row = {
      Individual  => sprintf("<small id=\"$data->{'Name'}\">$data->{'Name'} (%s)</small>", substr($data->{'Gender'}, 0, 1)),
      Genotype    => "<small>$genotype</small>",
      Population  => "<small>".join(", ", sort keys %{{map {$_->{Name} => undef} @{$data->{Population}}}})."</small>",
      Father      => "<small>".($father eq '-' ? $father : "<a href=\"#$father\">$father</a>")."</small>",
      Mother      => "<small>".($mother eq '-' ? $mother : "<a href=\"#$mother\">$mother</a>")."</small>",
      Children    => '-'
    };
    
    my @children = map { sprintf "<small><a href=\"#$_\">$_</a> (%s)</small>", substr($data->{'Children'}{$_}[0], 0, 1) } keys %{$data->{'Children'}};
    
    if (@children) {
      $row->{'Children'} = join ', ', @children;
      $flag_children = 1;
    }
    
    if ($other_ind == 1 && scalar(keys %populations) == 0) {  
      push @{$rows{'other_ind'}}, $row;
      ## need this to display if there is only one genotype for a sequenced individual
      $pop_names{"other_ind"} = "single individuals";
    }
    else {
      push @{$rows{$_}}, $row foreach keys %populations;
    }
  }
  
  my $columns = $self->get_table_headings;
  
  push @$columns, { key => 'Children', title => 'Children<br /><small>(Male/Female)</small>', sort => 'none', help => 'Children names and genders' } if $flag_children;
    
  
  if ($selected_pop || scalar keys %rows == 1) {
    $selected_pop ||= (keys %rows)[0]; # there is only one entry in %rows

    my $pop_name = $pop_names{$selected_pop};
    my $project_url  = $self->pop_url($pop_name);
    my $pop_url = ($project_url) ? sprintf('<div style="clear:both"></div><p><a href="%s" rel="external">More information about the <b>%s</b> population &rarr;</a></p>', $project_url, $pop_name) : ''; 

    return $self->toggleable_table(
      "Genotypes for $pop_names{$selected_pop}", $selected_pop, 
      $self->new_table($columns, $rows{$selected_pop}, { data_table => 1, sorting => [ 'Individual asc' ] }),
      1,
      qq{<span style="float:right"><a href="#}.$self->{'id'}.qq{_top">[back to top]</a></span><br />}
    ).$pop_url;
  }
  
  return $self->summary_tables(\%rows, \%priority_data, \%other_pop_data, \%other_ind_data, \%group_name, $columns);
}

sub summary_tables {
  my ($self, $rows, $priority_data, $other_pop_data, $other_ind_data, $group_name, $ind_columns) = @_;
  my $html; 

  $html .= qq{<a id="}.$self->{'id'}.qq{_top"></a>};
  
  # Population groups
  foreach my $priority_level (sort(keys %{$priority_data})){
    $html .= $self->format_table($rows, $priority_data->{$priority_level}, $group_name->{$priority_level} );
  }

  # Other populations 
  my $other_pop = (scalar(keys($priority_data)) > 0) ? 'Other populations' : 'Summary of genotypes by population';
  my $display_count = (scalar(keys($priority_data)) > 0) ? 1 : 0;
  $html .= $self->format_table($rows, $other_pop_data, $other_pop, $display_count )  if scalar(keys(%$other_pop_data)) > 0;

  # Other individuals
  $html .= $self->format_other_individuals_table($rows, 'Other individuals', $ind_columns ) if $rows->{'other_ind'};
 
  return $html;
}


sub format_table {
  my ($self, $rows, $pop_list, $table_header, $display_count) = @_;
  my (%pop_urls, $unique_urls, %urls_seen, $generic_pop_url);
  my $hub = $self->hub;
  my $html;

  my $table = $self->new_table([], [], { data_table => 1, download_table => 1 });

  $table->add_columns(
    { key => 'count',       title => 'Number of genotypes', width => '15%', sort => 'numeric', align => 'right'  },
    { key => 'view',        title => '',                    width => '5%',  sort => 'none',    align => 'center' },
    { key => 'Population',  title => 'Population',          width => '25%', sort => 'html'                       },
    { key => 'Description', title => 'Description',         width => '55%', sort => 'html'                       },
  );

  my $table_id = $table_header;
  $table_id =~ s/ /_/g;
  $table->add_option('id', $table_id);

  my %descriptions = map { $_->dbID => $_->description } @{$hub->get_adaptor('get_PopulationAdaptor', 'variation')->fetch_all_by_dbID_list([ keys %$pop_list ])};

  my $pop_count = (defined($display_count)) ? scalar(keys(%$pop_list)) : undef;

  # Get URLs
  foreach my $pop_id (keys %$pop_list) {
    my $url = $self->pop_url($pop_list->{$pop_id}{'name'}, $pop_list->{$pop_id}{'link'});
    $pop_urls{$pop_id} = $url;
    $urls_seen{$url}++;
  }

  if (scalar(keys %urls_seen) < 2) {
    my $key = (keys(%pop_urls))[0];
    $generic_pop_url = $pop_urls{$key};
  }

  # Get Rows
  foreach my $pop_id (sort { ($pop_list->{$a}{'name'} !~ /ALL/ cmp $pop_list->{$b}{'name'} !~ /ALL/) || $pop_list->{$a}{'name'} cmp $pop_list->{$b}{'name'} } keys %$pop_list) {
    my $row_count   = scalar @{$rows->{$pop_id}};
    my $pop_name    = $pop_list->{$pop_id}{'name'} || 'Other individuals';
    my $description = $descriptions{$pop_id} || '';
    my $full_desc   = $self->strip_HTML($description);

    if ($pop_name =~ /^.+\:.+$/) {
      my @composed_name = split(':', $pop_name);
      $composed_name[$#composed_name] = '<b>'.$composed_name[$#composed_name].'</b>';
      $pop_name = join(':',@composed_name);
    }

    $pop_name = scalar(keys %urls_seen) > 1 ? sprintf('<a href="%s" rel="external">%s</a>', $pop_urls{$pop_id}, $pop_name) : $pop_name; 

    if (length $description > 75 && $self->html_format) {
      while ($description =~ m/^.{75}.*?(\s|\,|\.)/g) {
        my $extra_desc =  substr($description, (pos $description));
           $extra_desc =~ s/,/ /g;
           $extra_desc = $self->strip_HTML($extra_desc);
        $description = qq{<span class="hidden export">$full_desc</span>} . substr($description, 0, (pos $description) - 1) . qq{... <span class="_ht" title="... $extra_desc">(more)</span>};
        last;
      }
    }

    $table->add_row({
      Population  => $pop_name,
      Description => $description,
      count       => $row_count,
      view        => $self->ajax_add($self->ajax_url(undef, { pop => $pop_id, update_panel => 1 }), $pop_id),
    });
  }    

  $table_header .= " ($pop_count)" if (defined($display_count));
  $html .= $self->toggleable_table($table_header, $table_id, $table, 1);

  if ($generic_pop_url) {
    my $project_name = ($table_header =~ /project/i) ? "<b>$table_header</b>" : ' ';
    $html .= sprintf('<div style="clear:both"></div><p><a href="%s" rel="external">More information about the %s populations &rarr;</a></p>', $generic_pop_url, $project_name);
  }

  return $html;
}

sub format_other_individuals_table {
  my ($self, $rows, $table_header, $ind_columns) = @_;
  my $html;
    
  my $ind_count = scalar @{$rows->{'other_ind'}};

  $html .= $self->toggleable_table(
    "$table_header ($ind_count)",'other_ind',
    $self->new_table($ind_columns, $rows->{'other_ind'}, { data_table => 1, sorting => [ 'Individual asc' ] }),
    0,
    qq{<span style="float:right"><a href="#}.$self->{'id'}.qq{_top">[back to top]</a></span><br />}
  );  
  
  return $html;
}


sub format_parent {
  my ($self, $parent_data) = @_;
  return ($parent_data && $parent_data->{'Name'}) ? $parent_data->{'Name'} : '-';
}


sub pop_url {
   ### Arg1        : Population name (to be displayed)
   ### Arg2        : dbSNP population ID (variable to be linked to)
   ### Example     : $self->pop_url($pop_name, $pop_dbSNPID);
   ### Description : makes pop_name into a link
   ### Returns  string

  my ($self, $pop_name, $pop_dbSNP) = @_;

  my $pop_url;

  if($pop_name =~ /^1000GENOMES/) {
    $pop_url = $self->hub->get_ExtURL('1KG_POP', $pop_name);
  }
  elsif ($pop_name =~ /^NextGen/i) {
    $pop_url = $self->hub->get_ExtURL('NEXTGEN_POP');
  }
  else {
    $pop_url = $pop_dbSNP ? $self->hub->get_ExtURL('DBSNPPOP', $pop_dbSNP->[0]) : undef;
  }
  return $pop_url;
}


sub get_table_headings {
  return [
    { key => 'Individual',  title => 'Individual<br /><small>(Male/Female/Unknown)</small>', sort => 'html', width => '20%', help => 'Individual name and gender'     },
    { key => 'Genotype',    title => 'Genotype<br /><small>(forward strand)</small>',        sort => 'html', width => '15%', help => 'Genotype on the forward strand' },
    { key => 'Population',  title => 'Population(s)',                                        sort => 'html', help => 'Populations to which this individual belongs'   },
    { key => 'Father',      title => 'Father',                                               sort => 'none'                                                           },
    { key => 'Mother',      title => 'Mother',                                               sort => 'none'                                                           }
  ];
}
    

1;
