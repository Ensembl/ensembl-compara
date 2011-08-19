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
	
	my $html = qq{
		<h2>1000 genomes alleles frequencies</h2>
    <input type="hidden" class="panel_type" value="PopulationGraph" />
	};
	
	my $legend = '';
	my $input  = '';
	my $graph  = '';
	my $gtitle = '';
	my $graph_id = 0;
	my $count    = 1;
	my $line_lim = 5;
	
	my @alleles;
	# Get alleles list
	foreach my $pop_name (sort(keys(%$pop_freq))) {
		my $values = '';
		my $p_name = (split(':',$pop_name))[1];
		foreach my $afreq (@{$pop_freq->{$pop_name}}) {
			my ($allele,$freq) = split(':',$afreq);
			
			if (!grep {$allele eq $_} @alleles) {
				push (@alleles, $allele);
			}
		}
	}	

	# Create graphs
	foreach my $pop_name (sort(keys(%$pop_freq))) {
		my $values = '';
		my @pop_names = (split(':',$pop_name));
		shift @pop_names;
		my $p_name = join(':',@pop_names);
		$p_name =~ /pilot_1_(.+)_low_coverage_panel/; # Gets a shorter name for the display
		my $short_name = ($1) ? $1 : $p_name;
		
		my @freqs;
		my $af;
		
		# Constructs the array for the pie charts: [allele,frequency]
		foreach my $al (@alleles) {
			my $al_flag = 0;
			my $al_freq = 0;
			foreach my $afreq (@{$pop_freq->{$pop_name}}) {
				my ($allele,$freq) = split(':',$afreq);
				if ($al eq $allele and $freq != 0)  {
					$values .= ',' if ($values ne '');
					$values .= "['$allele',$freq]";
					last;
				}
			}
		}	
		
		$input  .= qq{<input type="hidden" class="population" value="[$values]" />};
		$graph  .= qq{<td style="border:1px solid #000">&nbsp;<b>$short_name</b><div id="graphHolder$graph_id" style="width:118px;height:50px;"></div></td>};
		
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
  my $hub        = $self->hub;
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
				if ($freq ne 'unknown' and $freq != 0) {
        	push (@{$pop_freq->{$pop_name}}, "$gt:$freq");
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
	if (defined $number) {
		$number = $number*100;
	}
  return defined $number ? sprintf '%.2f', $number : 'unknown';
}


1;
