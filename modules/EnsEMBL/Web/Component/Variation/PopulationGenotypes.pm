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
      1000     => 1,
      HapMap   => 2,
      Other    => 3,
      Failed   => 4,
      Observed => 5,
    );
    
    my $species = $self->hub->species;
    foreach (sort {$table_order{(split /\s+/, $a->[0])[0]} <=> $table_order{(split /\s+/, $b->[0])[0]}} @$table_array) {
      my ($title, $table) = @$_;
      
      # hide "other" and "failed" table
      if ($title =~ /other|failed|population/i) {
        my $id = $title =~ /other/i ? 'other' : ($title =~ /failed/i ? 'failed' : 'nopop');
        my $expanded = ($id eq 'other' && $species ne 'Homo_sapiens') ? 1 : 0;
        $html .= $self->toggleable_table($title, $id, $table, $expanded);
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
    my ($tg_data, $hm_data, $fv_data, $no_pop_data);
    
    foreach my $pop_id (keys %$freq_data) {
      if ($pop_id eq 'no_pop') {
        $no_pop_data = delete $freq_data->{$pop_id};
        next;
      }
      
      my $name = $freq_data->{$pop_id}{'pop_info'}{'Name'};
    
      foreach my $ssid (keys %{$freq_data->{$pop_id}{'ssid'}}) {
        
        if ($freq_data->{$pop_id}{'ssid'}{$ssid}{'failed_desc'}) {
          $fv_data->{$pop_id}{'ssid'}{$ssid}                = delete $freq_data->{$pop_id}{'ssid'}{$ssid};
          $fv_data->{$pop_id}{'pop_info'}                 = $freq_data->{$pop_id}{'pop_info'};
          $fv_data->{$pop_id}{'ssid'}{$ssid}{'failed_desc'} =~ s/Variation submission/Variation submission $ssid/;
        } elsif ($name =~ /^1000genomes\:phase.*/i) {
          $tg_data->{$pop_id}{'ssid'}{$ssid} = delete $freq_data->{$pop_id}{'ssid'}{$ssid};
          $tg_data->{$pop_id}{'pop_info'}  = $freq_data->{$pop_id}{'pop_info'};
        } elsif ($name =~ /^cshl\-hapmap/i) {
          $hm_data->{$pop_id}{'ssid'}{$ssid} = delete $freq_data->{$pop_id}{'ssid'}{$ssid};
          $hm_data->{$pop_id}{'pop_info'}  = $freq_data->{$pop_id}{'pop_info'};
        }
      }
    }
    
    # recurse this method with just the tg_data and a flag to indicate it
    push @table_array,  @{$self->format_frequencies($tg_data, '1000 Genomes')} if $tg_data;
    push @table_array,  @{$self->format_frequencies($hm_data, 'HapMap')}       if $hm_data;
    push @table_array,  @{$self->format_frequencies($fv_data, 'Failed data')}  if $fv_data;
    
    # special method for data with no pop/freq data
    push @table_array,  ['Observed variant(s) without frequency or population', $self->no_pop_data($no_pop_data)]  if $no_pop_data;
  }
    
  foreach my $pop_id (keys %$freq_data) {
    my $pop_info = $freq_data->{$pop_id}{'pop_info'};
    
    foreach my $ssid (keys %{$freq_data->{$pop_id}{'ssid'}}) {
      my $data = $freq_data->{$pop_id}{'ssid'}{$ssid};
      my %pop_row;
      
      # SSID + Submitter
      if ($ssid) {
        $pop_row{'ssid'}      = $hub->get_ExtURL_link($ssid, 'DBSNPSS', $ssid) unless $ssid eq 'ss0';
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
      $pop_row{'pop'}              = $self->pop_url($pop_info->{'Name'}, $pop_info->{'PopLink'});
      $pop_row{'Description'}      = $pop_info->{'Description'} if $is_somatic;
      $pop_row{'failed'}           = $data->{'failed_desc'}             if $tg_flag =~ /failed/i;
      $pop_row{'Super-Population'} = $self->sort_extra_pops($pop_info->{'Super-Population'});
      $pop_row{'Sub-Population'}   = $self->sort_extra_pops($pop_info->{'Sub-Population'});
      $pop_row{'detail'}           = $self->ajax_add($self->ajax_url(undef, { function => 'IndividualGenotypes', pop => $pop_id, update_panel => 1 }), $pop_id) if ($pop_info->{Size});;
      
      # force ALL population to be displayed on top
      if($pop_info->{'Name'} =~ /ALL/) {
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
    unshift @header_row, { key => $col, align => 'left', title => $col, sort => 'numeric' };
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

sub no_pop_data {
  my ($self, $data) = @_;
  
  my $hub = $self->hub;
  
  # get reference alleles
  my $vfs = $self->object->Obj->get_all_VariationFeatures;
  
  my (@alleles, %alleles);
  
  if(scalar @$vfs) {
    my $vf = $vfs->[0];
    @alleles = split /\//, $vf->allele_string;
    %alleles = map {$_ => 1} @alleles;
  }
  
  my @rows;
  
  foreach my $sub(keys %$data) {
    foreach my $ss(keys %{$data->{$sub}}) {
      my %unique = map {$_ => 1} @{$data->{$sub}{$ss}};
      
      my @ss_alleles = sort {
        (($b eq $alleles[0]) <=> ($a eq $alleles[0])) ||
        (defined($alleles{$b}) <=> defined($alleles{$a}))
      } keys %unique;
      
      my $flag = 0;
      foreach(@ss_alleles) {
        $flag = 1 if !defined($alleles{$_});
      }
      
      push @rows, {
        ssid      => $hub->get_ExtURL_link($ss, 'DBSNPSS', $ss),
        submitter => $hub->get_ExtURL_link($sub, 'DBSNPSSID', $sub),
        alleles   =>
          join("/",
            map {defined($alleles{$_}) ? $_ : '<span style="color:red">'.$_.'</span>'}
            @ss_alleles
          ).
          ($flag ? ' *' : ''),
      };
    }
  }
  
  my $table = $self->new_table([], [], { data_table => 1, sorting => [ 'pop asc', 'submitter asc' ] });
  $table->add_columns(
    { key => 'ssid',      title => 'ssID'              },
    { key => 'submitter', title => 'Submitter'         },
    { key => 'alleles',   title => 'Submitted alleles' }
  );
  $table->add_rows(@rows);
  
  return $table;
}


1;
