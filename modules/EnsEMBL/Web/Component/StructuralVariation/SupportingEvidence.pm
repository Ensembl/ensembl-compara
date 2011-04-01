
package EnsEMBL::Web::Component::StructuralVariation::SupportingEvidence;

use strict;

use base qw(EnsEMBL::Web::Component);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}

sub content {
  my $self = shift;
  my $object 				= $self->object;
	my $hub           = $self->hub;
	my $supporting_sv	= $object->supporting_sv;
  my $html          = $self->supporting_evidence_table($supporting_sv);
	return $html;
}


sub supporting_evidence_table {
  my $self     = shift;
  my $ssvs     = shift;
  my $hub      = $self->hub;
	my $title    = 'Supporting evidence';
	my $table_id = 'evidence';
	
  my $columns = [
		 { key => 'ssv',   sort => 'position_html', title => 'Supporting evidence' },
		 { key => 'pos',   sort => 'position_html', title => 'Chr:bp' },
  ];

  my $rows = ();
  
	# Supporting evidences list
	if (scalar @{$ssvs}) {
		my $ssv_names = {};
		foreach my $ssv (@$ssvs){
			my $name = $ssv->name;
			$name =~ /(\d+)$/;
			my $ssv_nb = $1;
    	$ssv_names->{$1}{'name'} = $name;
			$ssv_names->{$1}{'sv'} = $ssv->is_structural_variation;
		}
		foreach my $ssv_n (sort {$a <=> $b} (keys(%$ssv_names))) {
			my $name = $ssv_names->{$ssv_n}{'name'};
			my $loc = '-';
			if ($ssv_names->{$ssv_n}{'sv'} ne '') {
				my $sv_obj = $ssv_names->{$ssv_n}{'sv'};
				
				# Name
				my $sv_link = $hub->url({
      									type   => 'StructuralVariation',
      									action => 'Summary',
      									sv     => $name,
											});
				$name = qq{<a href="$sv_link">$name</a>};
				
				# Location
				my $chr_bp = $sv_obj->seq_region_name . ':' . $sv_obj->seq_region_start . '-' . $sv_obj->seq_region_end;
				$loc = $hub->url({
      		type   => 'Location',
      		action => 'View',
					sv     => $name,
      		r      => $chr_bp,
    		});
				$loc = qq{<a href="$loc">$chr_bp</a>};
    	}
     	my %row = (
									ssv   => $name,
									pos   => $loc
      					);
				
      push @$rows, \%row;
		}
  	return $self->new_table($columns, $rows, { data_table => 1, sorting => [ 'location asc' ] })->render;
	}
	#else {
#		my $msg = 'No genes fall within the structural variant.<br /> Please, go to the <b>Context</b> page for more detailed information.';
#		return $self->_info('No genes', $msg, '50%');
#	}
}

sub supporting_evidence_table2 {
  my $self     = shift;
	my $sv       = shift;
  my $ssvs     = shift;
  my $hub      = $self->hub;
	my $title    = 'Supporting evidence';
	my $table_id = 'evidence';
	
  my $columns = [
	   { key => 'sv',   sort => 'position_html', title => 'Structural variation' },
		 { key => 'ssv',  sort => 'position_html', title => 'Supporting evidence' },
  ];

  my $rows = ();
  
	# Supporting evidences list
	if (scalar @{$ssvs}) {
		my $ssv_names = ();
		foreach my $ssv (@$ssvs){
    	push(@{$ssv_names},$ssv->name);
		}
		foreach my $ssv_n (sort(@$ssv_names)) {
     	my %row = (
									sv  => $sv,
									ssv => $ssv_n
      					);
				
      push @$rows, \%row;
		}
  	return $self->new_table($columns, $rows, { data_table => 1, sorting => [ 'location asc' ] })->render;
	}
	#else {
#		my $msg = 'No genes fall within the structural variant.<br /> Please, go to the <b>Context</b> page for more detailed information.';
#		return $self->_info('No genes', $msg, '50%');
#	}
}
1;
