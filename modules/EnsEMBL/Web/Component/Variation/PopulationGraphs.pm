package EnsEMBL::Web::Component::Variation::PopulationGraphs;

use strict;

use base qw(EnsEMBL::Web::Component::Variation);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}

sub content {
  my $self = shift;
  my $object = $self->object;
  my $hub = $self->hub;
  
  my $freq_data = $object->freqs;
  
  my $pop_freq = $self->format_frequencies($freq_data);
  return '' unless (defined($pop_freq));
  
  my @pop_phase1 = grep{ /phase_1/} keys(%$pop_freq);
  return '' unless (scalar @pop_phase1);
  
  my $html = qq{
    <h2>1000 Genomes allele frequencies</h2>
    <input type="hidden" class="panel_type" value="PopulationGraph" />
  };
  
  my $legend = '';
  my $input  = '';
  my $graph  = '';
  my $gtitle = '';
  my $graph_id = 0;
  my $count    = 1;
  my $line_lim = 5;
	my $height   = 50;
  
  my @alleles;
  # Get alleles list
  foreach my $pop_name (sort(keys(%$pop_freq))) {
    my $values = '';
    my $p_name = (split(':',$pop_name))[1];
    foreach my $ssid (keys %{$pop_freq->{$pop_name}}) {
			foreach my $allele (keys %{$pop_freq->{$pop_name}{$ssid}}) {
				my $freq = $pop_freq->{$pop_name}{$ssid}{$allele};
        push (@alleles, $allele) if ((!grep {$allele eq $_} @alleles) && $freq>0);
     	}
		}	
  }
	
	my $nb_alleles = scalar(@alleles);
	if ($nb_alleles>2) {
		while ($nb_alleles != 2) {
			$height += 5;
			$nb_alleles --;
		}
	}
 
  # Create graphs
  foreach my $pop_name (sort {($a !~ /ALL/) cmp ($b !~ /ALL/) || $a cmp $b} (@pop_phase1)) {
    
    my $values = '';
    my @pop_names = (split(':',$pop_name));
    shift @pop_names;
    my $p_name = join(':',@pop_names);
    $p_name =~ /phase_1_(.+)/; # Gets a shorter name for the display
    my $short_name = ($1) ? $1 : $p_name;
		
    # Constructs the array for the pie charts: [allele,frequency]
    foreach my $al (@alleles) {
			foreach my $ssid (keys %{$pop_freq->{$pop_name}}) {

        next if (!$pop_freq->{$pop_name}{$ssid}{$al});
					
			  my $freq = $pop_freq->{$pop_name}{$ssid}{$al};
					
        $values .= ',' if ($values ne '');
        $freq = 0.5 if ($freq < 0.5); # Fixed bug if freq between 0 and 0.5
        $values .= "['$al',$freq]";
        last;
    	}
		}
		
    my $border = $short_name eq 'ALL' ? '2px' : '1px';
    $input  .= qq{<input type="hidden" class="population" value="[$values]" />};
    $graph  .= qq{<td style="border:$border solid #000">&nbsp;<b>$short_name</b><div id="graphHolder$graph_id" style="width:118px;height:$height\px;"></div></td>};
    $graph  .= qq{<td style="width:15px"></td>} if ($short_name eq 'ALL');
    
    if ($count == $line_lim) { 
      $count = 0;
      $graph .= '</tr><tr>';
    }
    $graph_id ++;
    $count ++;
  } 

  $html .= $input;
  $html .= '<table>';
  $html .= "<tr>$graph</tr>";  
  $html .= '</table><br />'; 
  return $html;
}


sub format_frequencies {
  my ($self, $freq_data) = @_;
  my $hub = $self->hub;
  my $pop_freq;
  
   foreach my $pop_id (keys %$freq_data) {
    foreach my $ssid (keys %{$freq_data->{$pop_id}}) {
      my $pop_name = $freq_data->{$pop_id}{$ssid}{'pop_info'}{'Name'};
      next if($freq_data->{$pop_id}{$ssid}{'pop_info'}{'Name'} !~ /^1000genomes\:.*/i);
      next if($freq_data->{$pop_id}{$ssid}{failed_desc});
      # Freqs alleles ---------------------------------------------
      my @allele_freq = @{$freq_data->{$pop_id}{$ssid}{'AlleleFrequency'}};
      foreach my $gt (@{$freq_data->{$pop_id}{$ssid}{'Alleles'}}) {
        next unless $gt =~ /(\w|\-)+/;
        
        my $freq = $self->format_number(shift @allele_freq);
        if ($freq ne 'unknown') {
          $pop_freq->{$pop_name}{$ssid}{$gt} = $freq;
        }
      }
    }
  }
  return $pop_freq;
}


sub format_number {
  ### Population_genotype_alleles
  ### Arg1 : null or a number
  ### Returns "unknown" if null or formats the number to 3 decimal places

  my ($self, $number) = @_;
  $number = $number*100 if (defined $number);
  return defined $number ? sprintf '%.2f', $number : 'unknown';
}


1;
