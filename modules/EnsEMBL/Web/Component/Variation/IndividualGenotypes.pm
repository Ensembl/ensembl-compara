package EnsEMBL::Web::Component::Variation::IndividualGenotypes;

use strict;

use base qw(EnsEMBL::Web::Component::Variation);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}

sub get_table_headings
{
    my $self = shift;

    return (
        { key => 'Individual', title => 'Individual<br />(gender)', 
          sort => 'html', width => '20%' },
        { key => 'Genotype', title => 'Genotype<br />(forward strand)', 
          sort => 'html', width => '15%' },
        { key => 'Description', title => 'Description',                    
          sort => 'html', },
        #{ key => 'Populations', title => 'Populations', width => 250,      
          #sort => 'html' },
        { key => 'Father', title => 'Father',                         
          sort => 'none', },
        { key => 'Mother', title => 'Mother',                         
          sort => 'none', },
        #{ key => 'Children', title => 'Children',                         
        #  sort => 'none', }
    );
}

sub get_row_data
{
    my $self = shift;
    my $ind_name = shift;
    my $ind_gender = shift;
    my $genotype = shift;
    my $description = shift;
    #my $pop_string = shift;
    my $father = shift;
    my $mother = shift;
    
    return({
      Individual  => "<small>$ind_name (".substr($ind_gender, 0, 1).")</small>",
      Genotype    => "<small>$genotype</small>",
      Description => "<small>$description</small>",
      #Populations => "<small>$pop_string</small>",
      Father      => "<small>$father</small>",
      Mother      => "<small>$mother</small>",
      Children    => '-'
    });
}


sub content {
  my $self         = shift;
  my $object       = $self->object;
  my $html         = '';
  my $hub          = $self->hub;
  my $selected_pop = $hub->param('pop');

  ## first check we have uniquely determined variation
  if ( $object->not_unique_location ){
    return $self->_info(
      'A unique location can not be determined for this Variation',
      $object->not_unique_location
    );
  }

  ## return if no data
  my $pop_obj;
  
  if(defined($selected_pop)) {
    $pop_obj = $self->hub->get_adaptor('get_PopulationAdaptor', 'variation')->fetch_by_dbID($selected_pop);
  }
  
  my %ind_data = %{$object->individual_table($pop_obj)};
  
  return
    '<h3>No individual genotypes for this SNP'.
    (defined($selected_pop) ? ' in population '.$pop_obj->name : '').
    '</h3>' unless %ind_data;

  ## if data continue
  my %rows;
  my (%all_pops, %pop_names);
  my $flag_children = 0;
  
  # get alleles for colouring genotypes
  my $allele_string = $self->object->alleles;
  my @colour_order = qw/blue red green/;
  my %colours;
  foreach my $allele(split /\//, $allele_string) {
    $colours{$allele} = shift @colour_order || 'black';
  }
  
  foreach my $ind_id (sort { $ind_data{$a}{'Name'} cmp $ind_data{$b}{'Name'} } keys %ind_data) {
    my %ind_row;
    my $genotype = $ind_data{$ind_id}{'Genotypes'};
    
    next if $genotype eq '(indeterminate)';
    
    # Parents
    my $father = $self->format_parent($ind_data{$ind_id}{'Father'});
    my $mother = $self->format_parent($ind_data{$ind_id}{'Mother'});
    
    # Name, Gender, Desc
    my $description = uc $ind_data{$ind_id}{'Description'} || '-';
    
    my %populations;
    foreach my $pop(@{$ind_data{$ind_id}{'Population'}}) {
      my $pop_id = $pop->{'ID'};
      $populations{$pop_id} = 1;
      $all_pops{$pop_id} = $self->pop_url($pop->{'Name'}, $pop->{'Link'});
      $pop_names{$pop_id} = $pop->{'Name'};
    }
    
    $genotype =~ s/A/'<span style="color:red">'.$&.'<\/span>'/ge;
    $genotype =~ s/C/'<span style="color:blue">'.$&.'<\/span>'/ge;
    $genotype =~ s/G/'<span style="color:orange">'.$&.'<\/span>'/ge;
    $genotype =~ s/T/'<span style="color:green">'.$&.'<\/span>'/ge;
    
    #my @alleles = split /\|/, $genotype;
    #for my $i(0..$#alleles) {
    #  my $colour = $colours{$alleles[$i]} || 'black';
    #  $alleles[$i] = qq{<span style="color:$colour">$alleles[$i]</span>};
    #}
    #$genotype = join '|', @alleles;
    
    my $tmp_row = $self->get_row_data(
      $ind_data{$ind_id}{'Name'},
      $ind_data{$ind_id}{'Gender'},
      $genotype,
      $description,
      #$pop_string,
      $father,
      $mother,
    );
    
    # Children
    my $children = $ind_data{$ind_id}{'Children'};
    my @children = map { "<small>$_ (".substr($children->{$_}[0], 0, 1).")</small>" } keys %$children;
    
    if (@children) {
      $tmp_row->{'Children'} = join ', ', @children;
      $flag_children = 1;
    }
    
    push @{$rows{$_}}, $tmp_row foreach keys %populations;
  }  
  
  my $pop_adaptor = $hub->get_adaptor('get_PopulationAdaptor', 'variation');
  my %descriptions;
  $descriptions{$_->dbID} = $_->description foreach @{$pop_adaptor->fetch_all_by_dbID_list([keys %all_pops])};
  
  if(defined($selected_pop)) {
    my $table = $self->new_table([], [], {  data_table => 1, sorting => [ 'Individual asc' ], exportable => 0, id => "${selected_pop}_table"  });
    
    $table->add_columns($self->get_table_headings());
    $table->add_columns({ key => 'Children', title => 'Children', sort => 'none' }) if $flag_children;
    
    $table->add_rows(@{$rows{$selected_pop}});
    
    
    $html .= qq{
      <h2 style="float:left"><a href="#" class="toggle open" rel="$selected_pop">Genotypes for $pop_names{$selected_pop}</a></h2>
      <span style="float:right;"><a href="#$self->{'id'}_top">[back to top]</a></span>
      <p class="invisible">.</p>
    };
    
    $html .= sprintf '<div class="toggleable">%s</div>', $table->render;
  }
  
  else {
    my $od_table = $self->new_table([], [], {  data_table => 1, sorting => [ 'Population asc' ], exportable => 0 });
    my $hm_table = $self->new_table([], [], {  data_table => 1, sorting => [ 'Population asc' ], exportable => 0 });
    my $tg_table = $self->new_table([], [], {  data_table => 1, sorting => [ 'Population asc' ], exportable => 0 });
    
    foreach my $t($od_table, $hm_table, $tg_table) {
      $t->add_columns(
        { key => 'count',       title => 'Number of genotypes', width => '15%', sort => 'numeric', align => 'right'  },
        { key => 'view',        title => '',                    width => '5%',  sort => 'none',    align => 'center' },
        { key => 'Population',  title => 'Population',          width => '25%', sort => 'html'                       },
        { key => 'Description', title => 'Description',         width => '55%', sort => 'html'                       },
      );
    }
    
    my $other_row_count;
    
    foreach my $pop(sort keys %all_pops) {
      
      my $row_count = scalar @{$rows{$pop}};
      my $pop_name = $all_pops{$pop};
      
      my $url = $self->ajax_url . ";pop=$pop;update_panel=1";
      
      my $view_html = qq{
        <a href="$url" class="ajax_add toggle closed" rel="$pop">
          <span class="closed">Show</span><span class="open">Hide</span>
          <input type="hidden" class="url" value="$url" />
        </a>
      };
      
      my $description = $descriptions{$pop};
      my $full_desc = $description;
      
      if(length($description) > 75) {
        while($description =~ m/^.{75}.*?(\s|\,|\.)/g) {
          $description = substr($description, 0, (pos $description) - 1).'...(more)';
          last;
        }
      }
      
      my $t;
      
      if($pop_name =~ /cshl-hapmap/i) {
        $t = $hm_table;
      }
      elsif($pop_name =~ /1000genomes/i) {
        $t = $tg_table;
      }
      else {
        $t = $od_table;
        $other_row_count++;
      }
      
      $t->add_row({
        'Population'  => $pop_name,
        'Description' => "<span title='$full_desc'>".$description."</span>",
        'count'       => $row_count,
        'view'        => $view_html,
      });
    }
    
    $html .= qq{<a id="$self->{'id'}_top"></a>};
    
    if($tg_table->has_rows) {
      $html .= '<h2>1000 Genomes</h2>'.$tg_table->render;
    }
    
    if($hm_table->has_rows) {
      $html .= '<h2>HapMap</h2>'.$hm_table->render;
    }
    
    if($hm_table->has_rows || $tg_table->has_rows) {
      $od_table->add_option('data_table', 'toggle_table hide');
      $od_table->add_option('id', 'other_table');
      
      $html .= sprintf('
        <div class="toggle_button" id="other">
          <h2 style="float:left">Other data (%i)</h2>
          <em class="closed" style="margin:3px"></em>
          <p class="invisible">.</p>
        </div>
        %s
      ', $other_row_count, $od_table->render) if $od_table->has_rows;
    }
      
    else {     
      $html .= "<h2>Summary of genotypes by population</h2>" . $od_table->render;
    }
  }
  
  return $html;
}

sub format_parent {
  my ($self, $parent_data) = @_;
  return ($parent_data && $parent_data->{'Name'}) ? $parent_data->{'Name'} : '-';
}

sub pop_url {
  my ($self, $pop_name, $pop_dbSNP) = @_;
  return $pop_name unless $pop_dbSNP;
  return $self->hub->get_ExtURL_link($pop_name, 'DBSNPPOP', $pop_dbSNP->[0]);
}


1;
