# $Id$

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
  
  return $self->_info('A unique location can not be determined for this Variation', $object->not_unique_location) if $object->not_unique_location;  
  
  my $pop_obj  = $selected_pop ? $self->hub->get_adaptor('get_PopulationAdaptor', 'variation')->fetch_by_dbID($selected_pop) : undef;
  my %ind_data = %{$object->individual_table($pop_obj)};

  return sprintf '<h3>No individual genotypes for this SNP%s %s</h3>', $selected_pop ? ' in population' : '', $pop_obj->name unless %ind_data;

  my (%rows, %all_pops, %pop_names);
  my $flag_children = 0;
  my $allele_string = $self->object->alleles;
  my @colour_order  = qw(blue red green);
  my %colours       = map { $_ => shift @colour_order || 'black' } split /\//, $allele_string;
  
  foreach my $ind_id (sort { $ind_data{$a}{'Name'} cmp $ind_data{$b}{'Name'} } keys %ind_data) {
    my $data     = $ind_data{$ind_id};
    my $genotype = $data->{'Genotypes'};
    
    next if $genotype eq '(indeterminate)';
    
    my $father      = $self->format_parent($data->{'Father'});
    my $mother      = $self->format_parent($data->{'Mother'});
    my $description = $data->{'Description'} || '-';
    my %populations;
    
    foreach my $pop(@{$data->{'Population'}}) {
      my $pop_id = $pop->{'ID'};
      next unless $pop_id;
      
      $populations{$pop_id} = 1;
      $all_pops{$pop_id}    = $self->pop_url($pop->{'Name'}, $pop->{'Link'});
      $pop_names{$pop_id}   = $pop->{'Name'};
    }
    
    $genotype =~ s/A/<span style="color:green">A<\/span>/g;
    $genotype =~ s/C/<span style="color:blue">C<\/span>/g;
    $genotype =~ s/G/<span style="color:orange">G<\/span>/g;
    $genotype =~ s/T/<span style="color:red">T<\/span>/g;
    
    my $row = {
      Individual  => sprintf("<small>$data->{'Name'} (%s)</small>", substr($data->{'Gender'}, 0, 1)),
      Genotype    => "<small>$genotype</small>",
      Description => "<small>$description</small>",
      Father      => "<small>$father</small>",
      Mother      => "<small>$mother</small>",
      Children    => '-'
    };
    
    my @children = map { sprintf "<small>$_ (%s)</small>", substr($data->{'Children'}{$_}[0], 0, 1) } keys %{$data->{'Children'}};
    
    if (@children) {
      $row->{'Children'} = join ', ', @children;
      $flag_children = 1;
    }
    
    push @{$rows{$_}}, $row foreach keys %populations;
  }
  
  if ($selected_pop || scalar keys %rows == 1) {
    $selected_pop ||= (keys %rows)[0]; # there is only one entry in %rows
    
    my $columns = [
      { key => 'Individual',  title => 'Individual<br />(gender)',       sort => 'html', width => '20%' },
      { key => 'Genotype',    title => 'Genotype<br />(forward strand)', sort => 'html', width => '15%' },
      { key => 'Description', title => 'Description',                    sort => 'html'                 },
      { key => 'Father',      title => 'Father',                         sort => 'none'                 },
      { key => 'Mother',      title => 'Mother',                         sort => 'none'                 }
    ];
    
    push @$columns, { key => 'Children', title => 'Children', sort => 'none' } if $flag_children;
    
    return $self->toggleable_table(
      "Genotypes for $pop_names{$selected_pop}", $selected_pop, 
      $self->new_table($columns, $rows{$selected_pop}, { sorting => [ 'Individual asc' ] }),
      1,
      qq{<span style="float:right"><a href="#$self->{'id'}_top">[back to top]</a></span><br />}
    );
  }
  
  return $self->summary_tables(\%all_pops, \%rows);
}

sub summary_tables {
  my ($self, $all_pops, $rows) = @_;
  my $hub          = $self->hub;
  my $od_table     = $self->new_table([], [], { data_table => 1, download_table => 1, sorting => [ 'Population asc' ] });
  my $hm_table     = $self->new_table([], [], { data_table => 1, download_table => 1, sorting => [ 'Population asc' ] });
  my $tg_table     = $self->new_table([], [], { data_table => 1, download_table => 1, sorting => [ 'Population asc' ] });
  my %descriptions = map { $_->dbID => $_->description } @{$hub->get_adaptor('get_PopulationAdaptor', 'variation')->fetch_all_by_dbID_list([ keys %$all_pops ])};
  my ($other_row_count, $html);
  
  foreach ($od_table, $hm_table, $tg_table) {
    $_->add_columns(
      { key => 'count',       title => 'Number of genotypes', width => '15%', sort => 'numeric', align => 'right'  },
      { key => 'view',        title => '',                    width => '5%',  sort => 'none',    align => 'center' },
      { key => 'Population',  title => 'Population',          width => '25%', sort => 'html'                       },
      { key => 'Description', title => 'Description',         width => '55%', sort => 'html'                       },
    );
  }
  
  foreach my $pop (sort keys %$all_pops) {
    my $row_count   = scalar @{$rows->{$pop}};
    my $pop_name    = $all_pops->{$pop};
    my $description = $descriptions{$pop};
    my $full_desc   = $self->strip_HTML($description);
    
    if (length $description > 75 && $self->html_format) {
      while ($description =~ m/^.{75}.*?(\s|\,|\.)/g) {
        $description = substr($description, 0, (pos $description) - 1) . '...(more)';
        last;
      }
    }
    
    my $table;
    
    if ($pop_name =~ /cshl-hapmap/i) {        
      $table = $hm_table;
    } elsif($pop_name =~ /1000genomes/i) {        
      $table = $tg_table;
    } else {
      $table = $od_table;
      $other_row_count++;
    }
    
    $table->add_row({
      Population  => $pop_name,
      Description => qq{<span title="$full_desc">$description</span>},
      count       => $row_count,
      view        => $self->ajax_add($self->ajax_url(undef, { pop => $pop, update_panel => 1 }), $pop),
    });
  }    
  
  $html .= qq{<a id="$self->{'id'}_top"></a>};
  
  if ($tg_table->has_rows) {
    $tg_table->add_option('id', '1000genomes_table');
    $html .= '<h2>1000 Genomes</h2>' . $tg_table->render;      
  }
  
  if ($hm_table->has_rows) {
    $hm_table->add_option('id', 'hapmap_table');
    $html .= '<h2>HapMap</h2>' . $hm_table->render;
  }
  
  if ($od_table->has_rows && ($hm_table->has_rows || $tg_table->has_rows)) {
    if ($self->html_format) {
      $html .= $self->toggleable_table("Other data ($other_row_count)", 'other', $od_table);
    } else {
      $html .= '<h2>Other data</h2>' . $od_table->render;
    }
  } else {     
    $html .= '<h2>Summary of genotypes by population</h2>' . $od_table->render;
  }
  
  return $html;
}

sub format_parent {
  my ($self, $parent_data) = @_;
  return ($parent_data && $parent_data->{'Name'}) ? $parent_data->{'Name'} : '-';
}

sub pop_url {
  my ($self, $pop_name, $pop_dbSNP) = @_;
  return $pop_dbSNP ? $self->hub->get_ExtURL_link($pop_name, 'DBSNPPOP', $pop_dbSNP->[0]) : $pop_name;
}

1;
