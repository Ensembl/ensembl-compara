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

  my (%rows, %all_pops, %pop_names);
  my $flag_children = 0;
  my $allele_string = $self->object->alleles;
  my $al_colours = $self->object->get_allele_genotype_colours;
  
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
      }
      else {
        $populations{$pop_id} = 1;
        $all_pops{$pop_id}    = $self->pop_url($pop->{'Name'}, $pop->{'Link'});
        $pop_names{$pop_id}   = $pop->{'Name'};
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
      
    return $self->toggleable_table(
      "Genotypes for $pop_names{$selected_pop}", $selected_pop, 
      $self->new_table($columns, $rows{$selected_pop}, { data_table => 1, sorting => [ 'Individual asc' ] }),
      1,
      qq{<span style="float:right"><a href="#$self->{'id'}_top">[back to top]</a></span><br />}
    );
  }
  
  return $self->summary_tables(\%all_pops, \%rows, $columns);
}

sub summary_tables {
  my ($self, $all_pops, $rows, $ind_columns) = @_;
  my $hub          = $self->hub;
  my $od_table     = $self->new_table([], [], { data_table => 1, download_table => 1, sorting => [ 'Population asc' ] });
  my $hm_table     = $self->new_table([], [], { data_table => 1, download_table => 1, sorting => [ 'Population asc' ] });
  my $tg_table     = $self->new_table([], [], { data_table => 1, download_table => 1, sorting => [ 'Population asc' ] });
  my $mgp_table    = $self->new_table([], [], { data_table => 1, download_table => 1, sorting => [ 'Population asc' ] });
  my $ind_table    = $self->new_table([], [], { data_table => 1, download_table => 1, sorting => [ 'Individual asc' ] });
  my %descriptions = map { $_->dbID => $_->description } @{$hub->get_adaptor('get_PopulationAdaptor', 'variation')->fetch_all_by_dbID_list([ keys %$all_pops ])};
  my ($other_row_count, $html);
  
  foreach ($od_table, $hm_table, $tg_table, $mgp_table) {
    $_->add_columns(
      { key => 'count',       title => 'Number of genotypes', width => '15%', sort => 'numeric', align => 'right'  },
      { key => 'view',        title => '',                    width => '5%',  sort => 'none',    align => 'center' },
      { key => 'Population',  title => 'Population',          width => '25%', sort => 'html'                       },
      { key => 'Description', title => 'Description',         width => '55%', sort => 'html'                       },
    );
  }

  foreach my $pop (sort { ($a !~ /ALL/ cmp $b !~ /ALL/) || $a cmp $b } keys %$all_pops) {
    my $row_count   = scalar @{$rows->{$pop}};
    my $pop_name    = $all_pops->{$pop} || 'Other individuals';
    my $description = $descriptions{$pop} || '';
    my $full_desc   = $self->strip_HTML($description);
    
    if (length $description > 75 && $self->html_format) {
      while ($description =~ m/^.{75}.*?(\s|\,|\.)/g) {
        my $extra_desc =  substr($description, (pos $description));
           $extra_desc =~ s/,/ /g;
           $extra_desc = $self->strip_HTML($extra_desc);
        $description = qq{<span class="hidden export">$full_desc</span>} . substr($description, 0, (pos $description) - 1) . qq{... <span class="_ht" title="... $extra_desc">(more)</span>};
        last;
      }
    }
    
    my $table;
    
    
    if ($pop_name =~ /cshl-hapmap/i) {        
      $table = $hm_table;
    } elsif($pop_name =~ /1000genomes/i) {        
      $table = $tg_table;
    } elsif($pop_name =~ /Mouse_Genomes_Project/i) {        
      $table = $mgp_table;
    } else {
      $table = $od_table;
      $other_row_count++;
    }

    if ($pop_name =~ /^.+\:.+$/) {
      $pop_name =~ s/\:/\:<b>/;
      $pop_name .= '</b>';
    }
    
    $table->add_row({
      Population  => $pop_name,
      Description => $description,
      count       => $row_count,
      view        => $self->ajax_add($self->ajax_url(undef, { pop => $pop, update_panel => 1 }), $pop),
    });
  }    
  
  $html .= qq{<a id="$self->{'id'}_top"></a>};
  
  if ($tg_table->has_rows) {
    my $tg_id = '1000genomes_table';
    $tg_table->add_option('id', $tg_id);
    $html .= $self->toggleable_table('1000 Genomes', $tg_id, $tg_table, 1);      
  }
  
  if ($hm_table->has_rows) {
    my $hm_id = 'hapmap_table';
    $hm_table->add_option('id', $hm_id);
    $html .= $self->toggleable_table('HapMap', $hm_id, $hm_table, 1);
  }

  if ($mgp_table->has_rows) {
    my $mgp_id = 'mouse_genomes_table';
    $mgp_table->add_option('id', $mgp_id);
    $html .= $self->toggleable_table('Mouse Genomes Project', $mgp_id, $mgp_table, 1);
  }
  
  if ($od_table->has_rows && ($hm_table->has_rows || $tg_table->has_rows)) {
    if ($self->html_format) {
      $html .= $self->toggleable_table("Other populations ($other_row_count)", 'other', $od_table, 1);
    } else {
      $html .= '<h2>Other populations</h2>' . $od_table->render;
    }
  } else {     
    $html .= '<h2>Summary of genotypes by population</h2>' . $od_table->render;
  }
  
  # Other individuals table
  if ($rows->{'other_ind'}) {
    my $ind_count = scalar @{$rows->{'other_ind'}};
    
    $html .= $self->toggleable_table(
      "Other individuals ($ind_count)",'other_ind', 
      $self->new_table($ind_columns, $rows->{'other_ind'}, { data_table => 1, sorting => [ 'Individual asc' ] }), 
      0,
      qq{<span style="float:right"><a href="#$self->{'id'}_top">[back to top]</a></span><br />}
    );
  }
  
  return $html;
}

sub format_parent {
  my ($self, $parent_data) = @_;
  return ($parent_data && $parent_data->{'Name'}) ? $parent_data->{'Name'} : '-';
}

sub pop_url {
  my ($self, $pop_name, $pop_dbSNP) = @_;
  
  my $img_info = qq{<img src="/i/16/info.png" class="_ht" style="float:right;position:relative;top:2px;width:12px;height:12px;margin-left:4px" title="Click to see more information about the population" alt="i    nfo" />};
  my $pop_url;
  if($pop_name =~ /^1000GENOMES/) {
    $pop_url = $pop_name.$self->hub->get_ExtURL_link($img_info, '1KG_POP', $pop_name);
  }
  else {
    $pop_url = $pop_dbSNP ? $pop_name.$self->hub->get_ExtURL_link($img_info, 'DBSNPPOP', $pop_dbSNP->[0]) : $pop_name;
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
