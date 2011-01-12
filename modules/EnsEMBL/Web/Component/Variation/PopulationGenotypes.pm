# $Id$

package EnsEMBL::Web::Component::Variation::PopulationGenotypes;

use strict;

use base qw(EnsEMBL::Web::Component::Variation);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}

sub content {
  my $self   = shift;
  my $object = $self->object;

  ## Check we have uniquely determined variation
  return $self->_info('A unique location can not be determined for this Variation', $object->not_unique_location) if $object->not_unique_location;
 
  my $freq_data = $object->freqs;
  
  return $self->_info('Variation: ' . $object->name, '<p>No genotypes for this variation</p>') unless %$freq_data;
  
  my $html;
  my $table_array = $self->format_frequencies($freq_data);
  
  $html .= qq{<a id="IndividualGenotypesPanel_top"></a>};
  
  # count how many tables there are
  my $count = scalar @{$table_array};
  
  # only one table to render (non-human or if no 1KG data)
  if($count == 1) {
    $html .= $table_array->[0]->[1]->render;
  }
  
  # more than one table
  else {
    my %table_order = (
      '1000'   => 1,
      'HapMap' => 2,
      'Other'  => 3,
      'Failed' => 4,
    );
    
    foreach my $sub_array(sort {$table_order{(split /\s+/, $a->[0])[0]} <=> $table_order{(split /\s+/, $b->[0])[0]}} @{$table_array}) {
      
      my ($title, $table) = @{$sub_array};
      
      # hide "other" and "failed" table
      if ($title =~ /other|failed/i) {
        my $id = ($title =~ /other/i ? 'other_table' : 'failed_table');
        $table->add_option('data_table', 'toggle_table hide');
        $table->add_option('id', $id.'_table');
        
        $html .= sprintf('
          <div class="toggle_button" id="%s">
            <h2 style="float:left">%s</h2>
            <em class="closed" style="margin:3px"></em>
            <p class="invisible">.</p>
          </div>
          %s
        ', $id, $title, $table->render);
      }
      
      else {     
        $html .= "<h2>$title</h2>" . $table->render;
      }
    }
  }
  
  return $html;
}

sub format_frequencies {
  my ($self, $freq_data, $tg_flag) = @_;
  my $hub        = $self->hub;
  my $is_somatic = $self->object->Obj->is_somatic;
  my %columns;
  my @rows;
  
  my $table_array;
  
  my $table = $self->new_table([], [], { data_table => 1, sorting => [ 'pop asc', 'submitter asc' ] });
  
  # split off 1000 genomes, HapMap and failed if present
  if(!defined($tg_flag)) {
    my ($tg_data, $hm_data, $fv_data);
    
    foreach my $pop_id(keys %$freq_data) {
      foreach my $ssid(keys %{$freq_data->{$pop_id}}) {
        if($freq_data->{$pop_id}{$ssid}{'pop_info'}{'Name'} =~ /^1000genomes\:(low_coverage|exon|trio)/i) {
          $tg_data->{$pop_id}{$ssid} = $freq_data->{$pop_id}{$ssid};
          delete $freq_data->{$pop_id}{$ssid};
        }
        elsif($freq_data->{$pop_id}{$ssid}{'pop_info'}{'Name'} =~ /^cshl\-hapmap/i) {
          $hm_data->{$pop_id}{$ssid} = $freq_data->{$pop_id}{$ssid};
          delete $freq_data->{$pop_id}{$ssid};
        }
        elsif($freq_data->{$pop_id}{$ssid}{failed_desc} || $freq_data->{$pop_id}{$ssid}{'pop_info'}{'Name'} =~ /^1000genomes/i) {
          $fv_data->{$pop_id}{$ssid} = $freq_data->{$pop_id}{$ssid};
          $fv_data->{$pop_id}{$ssid}{failed_desc} ||= '1000 genomes data replaced by direct import';
          $fv_data->{$pop_id}{$ssid}{failed_desc} =~ s/Variation/'Variation '.$ssid/e;
          delete $freq_data->{$pop_id}{$ssid};
        }
      }
    }
    
    # recurse this method with just the tg_data and a flag to indicate it
    push @{$table_array},  @{$self->format_frequencies($tg_data, '1000 genomes')} if $tg_data;
    push @{$table_array},  @{$self->format_frequencies($hm_data, 'HapMap')} if $hm_data;
    push @{$table_array},  @{$self->format_frequencies($fv_data, 'Failed data')} if $fv_data;
  }

  foreach my $pop_id (keys %$freq_data) {
    foreach my $ssid (keys %{$freq_data->{$pop_id}}) {
      my %pop_row;
      
      # SSID + Submitter  -----------------------------------------
      if (defined($freq_data->{$pop_id}{$ssid}{'ssid'})) {
        my $submitter         = $freq_data->{$pop_id}{$ssid}{'submitter'};
        $pop_row{'ssid'}      = $hub->get_ExtURL_link($freq_data->{$pop_id}{$ssid}{'ssid'}, 'DBSNPSS', $freq_data->{$pop_id}{$ssid}{'ssid'}) unless $ssid eq 'ss0';
        $pop_row{'submitter'} = $hub->get_ExtURL_link($submitter, 'DBSNPSSID', $submitter);
      }  
      
      # Freqs alleles ---------------------------------------------
      my @allele_freq = @{$freq_data->{$pop_id}{$ssid}{'AlleleFrequency'}};
      
      foreach my $gt (@{$freq_data->{$pop_id}{$ssid}{'Alleles'}}) {
        next unless $gt =~ /(\w|\-)+/;
        
        my $allele_count = shift @{$freq_data->{$pop_id}{$ssid}{'AlleleCount'}} || undef;
        $pop_row{"Allele count"}{$gt} = $allele_count.' <strong>('.$gt.')</strong>' if defined $allele_count;
        
        my $freq = $self->format_number(shift @allele_freq);
        $pop_row{"Alleles&nbsp;<br />$gt"} = $freq;
      }
      
      $pop_row{"Allele count"} = join " / ", sort {(split /\(|\)/, $a)[1] cmp (split /\(|\)/, $b)[1]} values %{$pop_row{"Allele count"}} if $pop_row{"Allele count"};
      
      # Freqs genotypes ---------------------------------------------
      my @genotype_freq = @{$freq_data->{$pop_id}{$ssid}{'GenotypeFrequency'} || []};
      
      foreach my $gt (@{$freq_data->{$pop_id}{$ssid}{'Genotypes'}}) {
        my $freq = $self->format_number(shift @genotype_freq);
        $pop_row{"Genotypes&nbsp;<br />$gt"} = $freq;
        
        my $allele_count = shift @{$freq_data->{$pop_id}{$ssid}{'GenotypeCount'}} || undef;
        $pop_row{"Genotype count"}{$gt} = $allele_count.' <strong>('.$gt.')</strong>' if defined $allele_count;
      }
      
      $pop_row{"Genotype count"} = join " / ", sort {(split /\(|\)/, $a)[1] cmp (split /\(|\)/, $b)[1]} values %{$pop_row{"Genotype count"}} if $pop_row{"Genotype count"};
      
      
      # Add a name, size and description if it exists ---------------------------
      $pop_row{'pop'} =
        $self->pop_url(
          $freq_data->{$pop_id}{$ssid}{'pop_info'}{'Name'},
          $freq_data->{$pop_id}{$ssid}{'pop_info'}{'PopLink'}
        );
        #' ('.($freq_data->{$pop_id}{$ssid}{'pop_info'}{'Size'} || '-').')';
        
      $pop_row{'Description'} = $freq_data->{$pop_id}{$ssid}{'pop_info'}{'Description'} if $is_somatic;
      
      $pop_row{'failed'} = $freq_data->{$pop_id}{$ssid}{failed_desc} if $tg_flag =~ /failed/i;
      
      # Super and sub populations ----------------------------------------------
      my $super_string = $self->sort_extra_pops($freq_data->{$pop_id}{$ssid}{'pop_info'}{'Super-Population'});
      $pop_row{'Super-Population'} = $super_string;

      my $sub_string = $self->sort_extra_pops($freq_data->{$pop_id}{$ssid}{'pop_info'}{'Sub-Population'});
      $pop_row{'Sub-Population'} = $sub_string;
      
      my $url = $hub->url('Component', {
        action       => 'Web',
        function     => 'IndividualGenotypes',
        pop          => $pop_id,
        update_panel => 1
      });
      
      my $view_html = qq{
        <a href="$url" class="ajax_add toggle closed" rel="$pop_id">
          <span class="closed">Show</span><span class="open">Hide</span>
          <input type="hidden" class="url" value="$url" />
        </a>
      };
      
      $pop_row{'detail'} = $view_html;

      push @rows, \%pop_row;
      map { $columns{$_} = 1 } grep $pop_row{$_}, keys %pop_row;
    }
  }
  
 # Format table columns ------------------------------------------------------
  my @header_row;
  
  foreach my $col (sort { $b cmp $a } keys %columns) {
    next if $col =~ /pop|ssid|submitter|Description|detail|count|failed/;
    unshift @header_row, { key => $col, align => 'left', title => $col, sort => 'numerical' };
  }
  
  if (exists $columns{'ssid'}) {
    unshift @header_row, { key => 'submitter', align => 'left', title => 'Submitter', sort => 'html'   };
    unshift @header_row, { key => 'ssid',      align => 'left', title => 'ssID',      sort => 'string' };
  }
  
  if (exists $columns{'Description'}) {
    unshift @header_row, { key => 'Description', align => 'left', title => 'Description', sort => 'none' };
  }
  
  unshift @header_row, { key => 'pop', align =>'left', title => ($is_somatic ? 'Sample' : 'Population'), sort => 'html' };
  
  if (exists $columns{'Allele count'}) {
    push @header_row, { key => 'Allele count', align => 'left', title => 'Allele count', sort => 'none' };
  }
  
  if (exists $columns{'Genotype count'}) {
    push @header_row, { key => 'Genotype count', align => 'left', title => 'Genotype count', sort => 'none' };
  }
  
  if($self->object->counts->{'individuals'}) {
    push @header_row, { key => 'detail', align => 'left', title => 'Genotype detail', sort => 'none'};
  }
  
  if($columns{'failed'}) {
    push @header_row, { key => 'failed', align => 'left', title => 'Failed description', sort => 'string'};
  }
  
  $table->add_columns(@header_row);
  $table->add_rows(@rows);
  
  
  push @{$table_array}, [($tg_flag ? $tg_flag : 'Other data').' ('.(scalar @rows).')', $table];

  return $table_array;
}

sub format_number {
  ### Population_genotype_alleles
  ### Arg1 : null or a number
  ### Returns "unknown" if null or formats the number to 3 decimal places

  my ($self, $number) = @_;
  return defined $number ? sprintf '%.3f', $number : 'unknown';
}

sub sort_extra_pops {
  ### Population_table
  ### Arg1        : hashref with population data
  ### Example     :  my $super_string = sort_extra_pops($freq_data{$pop_id}{'pop_info'}{'Super-Population'});
  ### Description : returns string with Population name (size)<br> description
  ### Returns  string

  my ($self, $extra_pop) = @_;

  my @pops;
  
  foreach my $pop_id (keys %$extra_pop) {
    my $display_pop = $self->pop_url($extra_pop->{$pop_id}{'Name'}, $extra_pop->{$pop_id}{'PopLink'});
    my $size        = $extra_pop->{$pop_id}{'Size'};
    $size           = " (Size: $size)" if $size;
    my $string      = "$display_pop$size";
       $string     .= "<br /><small>$extra_pop->{$pop_id}{'Description'}</small>" if $extra_pop->{$pop_id}{'Description'};
  }
  
  return join '<br />', @pops;
}

sub pop_url {
   ### Arg1        : Population name (to be displayed)
   ### Arg2        : dbSNP population ID (variable to be linked to)
   ### Example     : $self->pop_url($pop_name, $pop_dbSNPID);
   ### Description : makes pop_name into a link
   ### Returns  string

  my ($self, $pop_name, $pop_dbSNP) = @_;
  return $pop_name unless $pop_dbSNP;
  return $self->hub->get_ExtURL_link($pop_name, 'DBSNPPOP', $pop_dbSNP->[0]);
}


1;
