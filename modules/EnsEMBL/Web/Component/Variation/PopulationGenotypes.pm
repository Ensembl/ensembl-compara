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
  
  my $table_array = $self->format_frequencies($freq_data);
  my $html        = '<a id="IndividualGenotypesPanel_top"></a>';
  
  if (scalar @$table_array == 1) {
    $html .= $table_array->[0]->[1]->render; # only one table to render (non-human or if no 1KG data)
  } else {
    my %table_order = (
      1000   => 1,
      HapMap => 2,
      Other  => 3,
      Failed => 4,
      Pilot  => 5,
    );
    
    foreach (sort {$table_order{(split /\s+/, $a->[0])[0]} <=> $table_order{(split /\s+/, $b->[0])[0]}} @$table_array) {
      my ($title, $table) = @$_;
      
      # hide "other" and "failed" table
      if ($title =~ /other|failed/i) {
        my $id = $title =~ /other/i ? 'other' : 'failed';
        $html .= $self->toggleable_table($title, $id, $table, 1);
      } elsif ($title =~ /pilot/i) {
        $html .= $self->toggleable_table($title, 'pilot', $table);
      } else {     
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
  my (%columns, @rows, @table_array);
  
  my $table = $self->new_table([], [], { data_table => 1, sorting => [ 'pop asc', 'submitter asc' ] });
  
  # split off 1000 genomes, HapMap and failed if present
  if (!$tg_flag) {
    my ($tg_data, $pi_data, $hm_data, $fv_data);
    
    foreach my $pop_id (keys %$freq_data) {
      foreach my $ssid (keys %{$freq_data->{$pop_id}}) {
        my $name = $freq_data->{$pop_id}{$ssid}{'pop_info'}{'Name'};
        
        if ($freq_data->{$pop_id}{$ssid}{'failed_desc'}) {
          $fv_data->{$pop_id}{$ssid}                = delete $freq_data->{$pop_id}{$ssid};
          $fv_data->{$pop_id}{$ssid}{'failed_desc'} =~ s/Variation submission/Variation submission $ssid/;
        } elsif ($name =~ /^1000genomes\:phase.*/i) {
          $tg_data->{$pop_id}{$ssid} = delete $freq_data->{$pop_id}{$ssid};
        } elsif ($name =~ /^1000genomes\:.*/i) {
          $pi_data->{$pop_id}{$ssid} = delete $freq_data->{$pop_id}{$ssid};
        } elsif ($name =~ /^cshl\-hapmap/i) {
          $hm_data->{$pop_id}{$ssid} = delete $freq_data->{$pop_id}{$ssid};
        }
      }
    }
    
    # recurse this method with just the tg_data and a flag to indicate it
    push @table_array,  @{$self->format_frequencies($tg_data, '1000 Genomes')} if $tg_data;
    push @table_array,  @{$self->format_frequencies($pi_data, 'Pilot 1000 Genomes')} if $pi_data;
    push @table_array,  @{$self->format_frequencies($hm_data, 'HapMap')}       if $hm_data;
    push @table_array,  @{$self->format_frequencies($fv_data, 'Failed data')}  if $fv_data;
  }
    
  foreach my $pop_id (keys %$freq_data) {
    foreach my $ssid (keys %{$freq_data->{$pop_id}}) {
      my $data = $freq_data->{$pop_id}{$ssid};
      my %pop_row;
      
      # SSID + Submitter
      if (defined $data->{'ssid'}) {
        $pop_row{'ssid'}      = $hub->get_ExtURL_link($data->{'ssid'}, 'DBSNPSS', $data->{'ssid'}) unless $ssid eq 'ss0';
        $pop_row{'submitter'} = $hub->get_ExtURL_link($data->{'submitter'}, 'DBSNPSSID', $data->{'submitter'});
      }  
      
      # Freqs alleles
      my @allele_freq = @{$data->{'AlleleFrequency'}};
      
      foreach my $gt (@{$data->{'Alleles'}}) {
        next unless $gt =~ /(\w|\-)+/;
        
        my $allele_count = shift @{$data->{'AlleleCount'}} || undef;
        
        $pop_row{'Allele count'}{$gt}      = "$allele_count <strong>($gt)</strong>" if defined $allele_count;
        $gt = substr($gt,0,10).'...' if (length($gt)>10);
        $pop_row{"Alleles&nbsp;<br />$gt"} = $self->format_number(shift @allele_freq);
      }
      
      $pop_row{'Allele count'} = join ' / ', sort {(split /\(|\)/, $a)[1] cmp (split /\(|\)/, $b)[1]} values %{$pop_row{'Allele count'}} if $pop_row{'Allele count'};
      
      # Freqs genotypes
      my @genotype_freq = @{$data->{'GenotypeFrequency'} || []};
      
      foreach my $gt (@{$data->{'Genotypes'}}) {
        my $genotype_count = shift @{$data->{'GenotypeCount'}} || undef;
        
        $pop_row{'Genotype count'}{$gt}      = "$genotype_count <strong>($gt)</strong>" if defined $genotype_count;
        $pop_row{"Genotypes&nbsp;<br />$gt"} = $self->format_number(shift @genotype_freq);
      }
      
      $pop_row{'Genotype count'}   = join ' / ', sort {(split /\(|\)/, $a)[1] cmp (split /\(|\)/, $b)[1]} values %{$pop_row{'Genotype count'}} if $pop_row{'Genotype count'};
      $pop_row{'pop'}              = $self->pop_url($data->{'pop_info'}{'Name'}, $data->{'pop_info'}{'PopLink'});
      $pop_row{'Description'}      = $data->{'pop_info'}{'Description'} if $is_somatic;
      $pop_row{'failed'}           = $data->{'failed_desc'}             if $tg_flag =~ /failed/i;
      $pop_row{'Super-Population'} = $self->sort_extra_pops($data->{'pop_info'}{'Super-Population'});
      $pop_row{'Sub-Population'}   = $self->sort_extra_pops($data->{'pop_info'}{'Sub-Population'});
      $pop_row{'detail'}           = $self->ajax_add($self->ajax_url(undef, { function => 'IndividualGenotypes', pop => $pop_id, update_panel => 1 }), $pop_id);
      
      # force ALL population to be displayed on top
      if($data->{'pop_info'}{'Name'} =~ /ALL/) {
        $pop_row{'pop'} = qq{<span class="hidden">0</span>}.$pop_row{'pop'};
      }

      push @rows, \%pop_row;
      
      $columns{$_} = 1 for grep $pop_row{$_}, keys %pop_row;
    }
  }
  
  # Format table columns
  my @header_row;
  
  foreach my $col (sort { $b cmp $a } keys %columns) {
    next if $col =~ /pop|ssid|submitter|Description|detail|count|failed/;
    unshift @header_row, { key => $col, align => 'left', title => $col, sort => 'numerical' };
  }
  
  if (exists $columns{'ssid'}) {
    unshift @header_row, { key => 'submitter', align => 'left', title => 'Submitter', sort => 'html'   };
    unshift @header_row, { key => 'ssid',      align => 'left', title => 'ssID',      sort => 'string' };
  }
  
  unshift @header_row, { key => 'Description',    align => 'left', title => 'Description',                           sort => 'none'   } if exists $columns{'Description'};
  unshift @header_row, { key => 'pop',            align => 'left', title => ($is_somatic ? 'Sample' : 'Population'), sort => 'html'   };
  push    @header_row, { key => 'Allele count',   align => 'left', title => 'Allele count',                          sort => 'none'   } if exists $columns{'Allele count'};
  push    @header_row, { key => 'Genotype count', align => 'left', title => 'Genotype count',                        sort => 'none'   } if exists $columns{'Genotype count'};
  push    @header_row, { key => 'detail',         align => 'left', title => 'Genotype detail',                       sort => 'none'   } if $self->object->counts->{'individuals'};
  push    @header_row, { key => 'failed',         align => 'left', title => 'Comment', width => '25%',               sort => 'string' } if $columns{'failed'};
  
  $table->add_columns(@header_row);
  $table->add_rows(@rows);
  
  push @table_array, [ sprintf('%s (%s)', $tg_flag || 'Other data', scalar @rows), $table ];

  return \@table_array;
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
       $size        = " (Size: $size)" if $size;
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
  
  my $pop_url;
  if($pop_name =~ /^1000GENOMES/) {
    $pop_url = $self->hub->get_ExtURL_link($pop_name, '1KG_POP'); 
  }
  else {
    $pop_url = $pop_dbSNP ? $self->hub->get_ExtURL_link($pop_name, 'DBSNPPOP', $pop_dbSNP->[0]) : $pop_name;
  }
  
  return $pop_url;
}


1;
